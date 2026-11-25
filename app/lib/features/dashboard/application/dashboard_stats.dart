// Everything the dashboard shows, computed from one hospital snapshot.
// Pure functions: no widgets, no providers, so they are easy to test.

import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';
import 'clock.dart';

/// One KPI tile (DashB: Total patients, In treatment, Ready for discharge,
/// Transfers today).
class KpiStat {
  const KpiStat({
    required this.label,
    required this.value,
    required this.trend,
    required this.delta,
  });

  final String label;
  final int value;

  /// Hourly values, oldest first, ending with [value] (sparkline).
  final List<double> trend;

  /// Change against one hour ago.
  final int delta;

  /// "↑ 3 vs last hour". Neutral colour: more patients is not good or bad.
  String get deltaText => delta == 0
      ? 'No change vs last hour'
      : '${delta > 0 ? '↑' : '↓'} ${delta.abs()} vs last hour';

  /// "up 3 versus last hour".
  String get deltaSpoken => delta == 0
      ? 'no change versus last hour'
      : '${delta > 0 ? 'up' : 'down'} ${delta.abs()} versus last hour';
}

/// A department row: occupancy colour + % + word ("Full" / "Bottleneck").
class DeptOccupancy {
  const DeptOccupancy({required this.department, required this.occupied});

  final Department department;
  final int occupied;

  String get code => department.code;
  int get beds => department.beds;
  int get free => (beds - occupied).clamp(0, beds);
  int get percent => beds == 0 ? 0 : (occupied * 100 / beds).round();

  /// Above 85% the ward is a bottleneck; at 100% it is full.
  String? get flag => percent >= 100
      ? 'Full'
      : percent > 85
      ? 'Bottleneck'
      : null;

  bool get isBottleneck => flag != null;
}

class DashboardStats {
  const DashboardStats({
    required this.kpis,
    required this.occupancy,
    required this.patients,
    required this.beds,
  });

  final List<KpiStat> kpis;

  /// All departments, highest occupancy first.
  final List<DeptOccupancy> occupancy;

  /// Patients in the hospital (not discharged).
  final int patients;
  final int beds;

  List<DeptOccupancy> get bottlenecks =>
      occupancy.where((d) => d.isBottleneck).toList();

  int get floors => occupancy.map((d) => d.department.floor).toSet().length;

  /// Number of hourly points in the KPI sparklines.
  static const int trendPoints = 8;

  static DashboardStats from(HospitalSnapshot s, DateTime now) {
    // Walk the history backwards from "now" and rebuild each patient's
    // status at every hourly checkpoint (null = not admitted yet).
    final status = <String, PatientStatus?>{
      for (final p in s.patients) p.id: p.status,
    };
    final today = startOfDay(now);
    final checkpoints = [
      for (var k = trendPoints - 1; k >= 0; k--)
        now.subtract(Duration(hours: k)),
    ];
    final transfers = s.events
        .whereType<LocationEvent>()
        .where((e) => !e.isAdmission && !e.at.isBefore(today))
        .toList();

    final total = List<double>.filled(trendPoints, 0);
    final inTreatment = List<double>.filled(trendPoints, 0);
    final ready = List<double>.filled(trendPoints, 0);
    final moved = List<double>.filled(trendPoints, 0);

    var e = 0;
    for (var i = trendPoints - 1; i >= 0; i--) {
      final at = checkpoints[i];
      // Undo every event that happened after this checkpoint. The newest
      // checkpoint is "now": future-dated events (other clocks) count as now.
      while (e < s.events.length &&
          (i < trendPoints - 1 && s.events[e].at.isAfter(at))) {
        switch (s.events[e]) {
          case StatusEvent(:final patientId, :final from):
            if (status.containsKey(patientId)) status[patientId] = from;
          case LocationEvent(:final patientId, :final isAdmission):
            if (isAdmission) status[patientId] = null;
        }
        e++;
      }
      var t = 0, it = 0, r = 0;
      for (final v in status.values) {
        if (v == null || v == PatientStatus.discharged) continue;
        t++;
        if (v == PatientStatus.inTreatment) it++;
        if (v == PatientStatus.readyForDischarge) r++;
      }
      total[i] = t.toDouble();
      inTreatment[i] = it.toDouble();
      ready[i] = r.toDouble();
      moved[i] = i == trendPoints - 1
          ? transfers.length.toDouble()
          : transfers.where((x) => !x.at.isAfter(at)).length.toDouble();
    }

    KpiStat kpi(String label, List<double> trend) => KpiStat(
      label: label,
      value: trend.last.round(),
      trend: trend,
      delta: (trend.last - trend[trendPoints - 2]).round(),
    );

    final occupancy = [
      for (final d in s.departments)
        DeptOccupancy(department: d, occupied: s.occupancy(d.code)),
    ]..sort((a, b) => b.percent.compareTo(a.percent));

    return DashboardStats(
      kpis: [
        kpi('Total patients', total),
        kpi('In treatment', inTreatment),
        kpi('Ready for discharge', ready),
        kpi('Transfers today', moved),
      ],
      occupancy: occupancy,
      patients: total.last.round(),
      beds: s.departments.fold(0, (sum, d) => sum + d.beds),
    );
  }
}

/// Newest transfers (nurse, admin) or status changes (doctor) for the feed.
List<HistoryEvent> recentFeed(
  HospitalSnapshot s,
  UserRole role, {
  int limit = 4,
}) {
  final events = role == UserRole.doctor
      ? s.events.whereType<StatusEvent>()
      : s.events.whereType<LocationEvent>().where((e) => !e.isAdmission);
  return events.take(limit).toList();
}

/// Doctor card: "5 of your patients are ready".
int readyInDepartment(HospitalSnapshot s, String? code) => code == null
    ? 0
    : s.patients
          .where(
            (p) =>
                p.location == code &&
                p.status == PatientStatus.readyForDischarge,
          )
          .length;

/// "Your departments · Most used this week": home first, then the wards
/// this person touched most in the last 7 days, then the fullest ones.
List<Department> yourDepartments(
  HospitalSnapshot s,
  StaffMember me,
  DateTime now, {
  int limit = 4,
}) {
  final weekAgo = now.subtract(const Duration(days: 7));
  final score = <String, int>{};
  void bump(String? code) {
    if (code != null) score[code] = (score[code] ?? 0) + 1;
  }

  for (final e in s.events) {
    if (e.byName != me.name || e.at.isBefore(weekAgo)) continue;
    switch (e) {
      case LocationEvent(:final from, :final to):
        bump(from);
        bump(to);
      case StatusEvent(:final patientId):
        bump(s.patient(patientId)?.location);
    }
  }
  int pct(Department d) =>
      d.beds == 0 ? 0 : s.occupancy(d.code) * 100 ~/ d.beds;
  final ordered = [...s.departments]
    ..sort((a, b) {
      if (a.code == me.homeDepartment) return -1;
      if (b.code == me.homeDepartment) return 1;
      final byScore = (score[b.code] ?? 0).compareTo(score[a.code] ?? 0);
      return byScore != 0 ? byScore : pct(b).compareTo(pct(a));
    });
  return ordered.take(limit).toList();
}

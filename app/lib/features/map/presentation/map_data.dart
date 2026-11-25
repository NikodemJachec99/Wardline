// Read-only figures the map, the department sheet, analytics and the ward
// monitor derive from a HospitalSnapshot. No writes anywhere in here.

import '../../../core/format.dart';
import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';
import 'map_geometry.dart';

/// Above this occupancy a department is a bottleneck (design: "> 85%").
const int kBottleneckPercent = 85;

/// "Now" for today's figures. The demo replays the design day at a fixed
/// clock in tests and screenshots; then the newest event is "now".
DateTime snapshotNow(HospitalSnapshot s) {
  final now = DateTime.now();
  if (s.events.isEmpty) return now;
  final latest = s.events.first.at;
  return now.difference(latest).inHours.abs() >= 12 ? latest : now;
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int percentOf(int occupied, int beds) =>
    beds == 0 ? 0 : (occupied * 100 / beds).round();

class DeptOccupancy {
  const DeptOccupancy(this.department, this.occupied);

  final Department department;
  final int occupied;

  int get beds => department.beds;
  int get percent => percentOf(occupied, beds);
  int get free => (beds - occupied).clamp(0, beds);
  bool get bottleneck => percent > kBottleneckPercent;
  bool get full => free == 0;

  /// "Full" / "Bottleneck" in words (never colour alone), else null.
  String? get flag => full
      ? 'Full'
      : bottleneck
      ? 'Bottleneck'
      : null;

  /// "Internal Medicine, 29 of 32 beds, 91 percent, bottleneck".
  String get spoken =>
      '${department.name}, $occupied of $beds beds, $percent percent'
      '${bottleneck ? ', bottleneck' : ''}';
}

DeptOccupancy occupancyOf(HospitalSnapshot s, Department d) =>
    DeptOccupancy(d, s.occupancy(d.code));

/// Patients currently in [code], newest arrival first.
List<Patient> patientsIn(HospitalSnapshot s, String code) =>
    s.patients
        .where(
          (p) => p.location == code && p.status != PatientStatus.discharged,
        )
        .toList()
      ..sort((a, b) => b.locationSince.compareTo(a.locationSince));

Map<PatientStatus, int> breakdownFor(HospitalSnapshot s, String code) {
  final out = <PatientStatus, int>{};
  for (final p in patientsIn(s, code)) {
    out[p.status] = (out[p.status] ?? 0) + 1;
  }
  return out;
}

List<LocationEvent> transfersToday(HospitalSnapshot s) {
  final now = snapshotNow(s);
  return s.events
      .whereType<LocationEvent>()
      .where((e) => !e.isAdmission && sameDay(e.at, now) && !e.at.isAfter(now))
      .toList();
}

class DeptDayStats {
  const DeptDayStats({
    required this.inToday,
    required this.outToday,
    required this.dischargesToday,
    required this.averageStay,
    required this.lastTransfer,
  });

  final int inToday;
  final int outToday;
  final int dischargesToday;

  /// Average time the current patients have been here; null when empty.
  final Duration? averageStay;

  /// "10:38 · Adam Wójcik ← ER"; null when nobody moved here yet.
  final String? lastTransfer;
}

DeptDayStats dayStats(HospitalSnapshot s, String code) {
  final now = snapshotNow(s);
  final today = transfersToday(s);
  final patients = patientsIn(s, code);
  final ids = {for (final p in s.patients) p.id: p};
  final discharges = s.events.whereType<StatusEvent>().where(
    (e) =>
        e.to == PatientStatus.discharged &&
        sameDay(e.at, now) &&
        ids[e.patientId]?.location == code,
  );
  Duration? avg;
  if (patients.isNotEmpty) {
    final total = patients.fold<int>(
      0,
      (sum, p) => sum + now.difference(p.locationSince).inMinutes.abs(),
    );
    avg = Duration(minutes: total ~/ patients.length);
  }
  String? last;
  for (final e in s.events.whereType<LocationEvent>()) {
    if (e.isAdmission || (e.to != code && e.from != code)) continue;
    final name = ids[e.patientId]?.fullName ?? 'Patient';
    last = e.to == code
        ? '${hm(e.at)} · $name ← ${e.from}'
        : '${hm(e.at)} · $name → ${e.to}';
    break;
  }
  return DeptDayStats(
    inToday: today.where((e) => e.to == code).length,
    outToday: today.where((e) => e.from == code).length,
    dischargesToday: discharges.length,
    averageStay: avg,
    lastTransfer: last,
  );
}

/// "48 min", "6.5 h", "4.6 d".
String stayLabel(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${(d.inMinutes / 60).toStringAsFixed(1)} h';
  return '${(d.inMinutes / 1440).toStringAsFixed(1)} d';
}

/// One stop of a patient's route today.
class RouteStop {
  const RouteStop({
    required this.department,
    required this.at,
    required this.current,
    this.liftNote,
  });

  final Department department;
  final DateTime at;

  /// The patient is here now (last stop).
  final bool current;

  /// "lift ↑ Floor 1" when the floor changed to get here.
  final String? liftNote;
}

/// Stops from the patient's location events today, oldest first. Falls back
/// to the current location when nothing moved today.
List<RouteStop> routeToday(HospitalSnapshot s, String patientId) {
  final p = s.patient(patientId);
  if (p == null) return const [];
  final now = snapshotNow(s);
  final events =
      s.events
          .whereType<LocationEvent>()
          .where((e) => e.patientId == patientId && sameDay(e.at, now))
          .toList()
        ..sort((a, b) => a.at.compareTo(b.at));
  final stops = <RouteStop>[];
  Department? prev;
  final raw = events.isEmpty
      ? [(p.location, p.locationSince)]
      : [for (final e in events) (e.to, e.at)];
  for (final (i, (code, at)) in raw.indexed) {
    final d = s.department(code);
    if (d == null) continue;
    String? note;
    if (prev != null && prev.floor != d.floor) {
      note = 'lift ${d.floor > prev.floor ? '↑' : '↓'} ${floorName(d.floor)}';
    }
    stops.add(
      RouteStop(
        department: d,
        at: at,
        current: i == raw.length - 1 && code == p.location,
        liftNote: note,
      ),
    );
    prev = d;
  }
  return stops;
}

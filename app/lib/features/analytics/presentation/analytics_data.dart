// Read-only figures for Analytics and the ward monitor, derived from the
// snapshot (the Supabase build reads the SQL views from PLAN §8.2 instead).

import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';
import '../../map/presentation/map_data.dart';

/// Today's numbers for the Analytics screen.
class AnalyticsDay {
  AnalyticsDay._({
    required this.now,
    required this.patientsInHouse,
    required this.changeSince7,
    required this.occupied,
    required this.beds,
    required this.transfers,
    required this.perHour,
    required this.wardStay,
    required this.wardCount,
    required this.departments,
    required this.deltaSince7,
    required this.flows,
    required this.nfc,
    required this.qr,
    required this.latest,
  });

  factory AnalyticsDay.of(HospitalSnapshot s) {
    final now = snapshotNow(s);
    final seven = DateTime(now.year, now.month, now.day, 7);
    final inHouse = s.patients
        .where((p) => p.status != PatientStatus.discharged)
        .toList();
    final today = transfersToday(s);
    final perHour = List<int>.filled(24, 0);
    for (final e in today) {
      perHour[e.at.hour]++;
    }
    final admissions7 = s.events.whereType<LocationEvent>().where(
      (e) => e.isAdmission && !e.at.isBefore(seven) && !e.at.isAfter(now),
    );
    final discharges7 = s.events.whereType<StatusEvent>().where(
      (e) =>
          e.to == PatientStatus.discharged &&
          !e.at.isBefore(seven) &&
          !e.at.isAfter(now),
    );
    final delta = <String, int>{for (final d in s.departments) d.code: 0};
    for (final e in today.where((e) => !e.at.isBefore(seven))) {
      if (e.from != null) delta[e.from!] = (delta[e.from!] ?? 0) - 1;
      delta[e.to] = (delta[e.to] ?? 0) + 1;
    }
    for (final e in admissions7) {
      delta[e.to] = (delta[e.to] ?? 0) + 1;
    }
    final wards = s.departments
        .where(
          (d) => d.kind == DepartmentKind.ward || d.kind == DepartmentKind.icu,
        )
        .map((d) => d.code)
        .toSet();
    final wardPatients = inHouse.where((p) => wards.contains(p.location));
    Duration? stay;
    if (wardPatients.isNotEmpty) {
      final mins = wardPatients.fold<int>(
        0,
        (a, p) => a + now.difference(p.admittedAt).inMinutes.abs(),
      );
      stay = Duration(minutes: mins ~/ wardPatients.length);
    }
    final flows = <(String, String), int>{};
    for (final e in today) {
      final k = (e.from!, e.to);
      flows[k] = (flows[k] ?? 0) + 1;
    }
    return AnalyticsDay._(
      now: now,
      patientsInHouse: inHouse.length,
      changeSince7: admissions7.length - discharges7.length,
      occupied: inHouse.length,
      beds: s.departments.fold(0, (a, d) => a + d.beds),
      transfers: today,
      perHour: perHour,
      wardStay: stay,
      wardCount: wards.length,
      departments: [for (final d in s.departments) occupancyOf(s, d)],
      deltaSince7: delta,
      flows: flows,
      nfc: today.where((e) => e.identifiedBy == 'NFC').length,
      qr: today.where((e) => e.identifiedBy == 'QR').length,
      latest: today.isEmpty ? null : today.first,
    );
  }

  final DateTime now;
  final int patientsInHouse;

  /// Admissions minus discharges since 07:00.
  final int changeSince7;
  final int occupied;
  final int beds;

  /// Newest first.
  final List<LocationEvent> transfers;

  /// Transfers per hour of the day (0–23).
  final List<int> perHour;

  /// Average time since admission for patients on inpatient wards.
  final Duration? wardStay;
  final int wardCount;
  final List<DeptOccupancy> departments;

  /// Patients now vs 07:00, per department.
  final Map<String, int> deltaSince7;

  /// (from, to) → transfers today.
  final Map<(String, String), int> flows;
  final int nfc;
  final int qr;
  final LocationEvent? latest;

  int get occupancyPercent => percentOf(occupied, beds);

  /// Hour with the most transfers (earliest on a tie); null on an empty day.
  int? get peakHour {
    int? best;
    for (var h = 0; h < 24; h++) {
      if (perHour[h] == 0) continue;
      if (best == null || perHour[h] > perHour[best]) best = h;
    }
    return best;
  }

  List<DeptOccupancy> get bottlenecks =>
      departments.where((d) => d.bottleneck).toList()
        ..sort((a, b) => b.percent.compareTo(a.percent));
}

/// "09:00–10:00".
String hourRange(int h) =>
    '${h.toString().padLeft(2, '0')}:00–${((h + 1) % 24).toString().padLeft(2, '0')}:00';

/// "Dr Piotr Zając" → "Dr P. Zając"; "Ewa Lis" → "E. Lis".
String shortStaffName(String name) {
  final parts = name.split(' ');
  final dr = parts.first == 'Dr';
  final rest = dr ? parts.sublist(1) : parts;
  if (rest.length < 2) return name;
  final short = '${rest.first[0]}. ${rest.sublist(1).join(' ')}';
  return dr ? 'Dr $short' : short;
}

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Friday 13 November".
String longDate(DateTime t) =>
    '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';

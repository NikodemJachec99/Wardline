import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/data/hospital_repository.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/dashboard/application/dashboard_stats.dart';

// KPI logic on a small hand-made hospital, so every number is checkable.
final _now = DateTime(2026, 11, 13, 10, 46);

Department _dept(String code) => Department(
  code: code,
  name: code,
  kind: DepartmentKind.ward,
  floor: 1,
  beds: 10,
  map: const MapRect(0, 0, 1, 1),
);

Patient _patient(String id, PatientStatus status, String location) => Patient(
  id: id,
  code: 'HPT-0000000$id',
  firstName: 'P',
  lastName: id,
  age: 40,
  condition: 'Observation',
  admittedAt: _now.subtract(const Duration(days: 2)),
  location: location,
  locationSince: _now,
  status: status,
  statusSince: _now,
  version: 1,
);

LocationEvent _move(String id, String patient, DateTime at, {String? from}) =>
    LocationEvent(
      id: id,
      patientId: patient,
      at: at,
      byName: 'Anna Nowak',
      byRole: UserRole.nurse,
      from: from,
      to: 'WARD',
    );

HospitalSnapshot _snapshot() => HospitalSnapshot(
  departments: [_dept('ER'), _dept('WARD')],
  staff: const [],
  patients: [
    _patient('1', PatientStatus.inTreatment, 'WARD'),
    _patient('2', PatientStatus.readyForDischarge, 'WARD'),
    _patient('3', PatientStatus.discharged, 'WARD'),
    _patient('4', PatientStatus.admitted, 'ER'),
  ],
  // Newest first, like the repository.
  events: [
    _move('t-today', '1', DateTime(2026, 11, 13, 10, 30), from: 'ER'),
    _move('admit-4', '4', DateTime(2026, 11, 13, 10, 15)),
    StatusEvent(
      id: 's-2',
      patientId: '2',
      at: DateTime(2026, 11, 13, 10, 10),
      byName: 'Dr Piotr Lis',
      byRole: UserRole.doctor,
      from: PatientStatus.inTreatment,
      to: PatientStatus.readyForDischarge,
    ),
    _move('t-yesterday', '1', DateTime(2026, 11, 12, 15), from: 'WARD'),
  ],
  syncedAt: _now,
);

void main() {
  final stats = DashboardStats.from(_snapshot(), _now);
  KpiStat kpi(String label) => stats.kpis.firstWhere((k) => k.label == label);

  test('four KPIs in design order', () {
    expect(stats.kpis.map((k) => k.label), [
      'Total patients',
      'In treatment',
      'Ready for discharge',
      'Transfers today',
    ]);
  });

  test('discharged patients are not counted', () {
    expect(kpi('Total patients').value, 3);
    expect(stats.patients, 3);
  });

  test('in treatment and ready for discharge count current statuses', () {
    expect(kpi('In treatment').value, 1);
    expect(kpi('Ready for discharge').value, 1);
  });

  test('transfers today skip admissions and earlier days', () {
    expect(kpi('Transfers today').value, 1);
  });

  test('delta compares with one hour ago', () {
    // 09:46: patient 4 not admitted yet, patient 2 still in treatment,
    // no transfer yet today.
    expect(kpi('Total patients').delta, 1);
    expect(kpi('In treatment').delta, -1);
    expect(kpi('Ready for discharge').delta, 1);
    expect(kpi('Transfers today').delta, 1);
  });

  test('sparkline has one point per hour and ends at the value', () {
    for (final k in stats.kpis) {
      expect(k.trend, hasLength(DashboardStats.trendPoints));
      expect(k.trend.last, k.value.toDouble());
    }
  });

  test('delta text and spoken delta', () {
    KpiStat withDelta(int d) =>
        KpiStat(label: 'X', value: 5, trend: const [], delta: d);
    expect(withDelta(3).deltaText, '↑ 3 vs last hour');
    expect(withDelta(-2).deltaText, '↓ 2 vs last hour');
    expect(withDelta(0).deltaText, 'No change vs last hour');
    expect(withDelta(3).deltaSpoken, 'up 3 versus last hour');
    expect(withDelta(-2).deltaSpoken, 'down 2 versus last hour');
    expect(withDelta(0).deltaSpoken, 'no change versus last hour');
  });
}

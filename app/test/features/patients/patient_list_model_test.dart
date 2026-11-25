import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/patients/presentation/patient_list_model.dart';

import '../../helpers/harness.dart';

void main() {
  final snap = demoRepository().current;

  test('128 patients grouped by department in hospital order', () {
    final all = visiblePatients(snap, const PatientFilter(), '');
    final groups = groupByDepartment(snap, all);
    expect(all, hasLength(128));
    expect(groups, hasLength(12));
    expect(groups.fold<int>(0, (n, g) => n + g.patients.length), 128);
    expect(groups.first.department.code, 'ER');
    expect(groups.first.patients, hasLength(19));
    for (final g in groups) {
      final names = g.patients.map((p) => p.lastName).toList();
      expect(names, [...names]..sort());
    }
  });

  test('search by name, ID (with or without dash), department', () {
    String names(String q) => visiblePatients(
      snap,
      const PatientFilter(),
      q,
    ).map((p) => p.fullName).join(',');
    expect(names('Kowalczyk'), 'Jan Kowalczyk');
    expect(names('kowalczyk'), 'Jan Kowalczyk');
    expect(names('HPT-7K3M9QX2'), 'Jan Kowalczyk');
    expect(names('hpt7k3m9qx2'), 'Jan Kowalczyk');
    expect(names('zielinska'), contains('Maria Zielińska'));
    expect(
      visiblePatients(snap, const PatientFilter(), 'Intensive'),
      hasLength(8),
    );
    expect(visiblePatients(snap, const PatientFilter(), 'ICU'), hasLength(8));
  });

  test('filters combine status, department and age', () {
    const ready = PatientFilter(statuses: {PatientStatus.readyForDischarge});
    expect(visiblePatients(snap, ready, ''), hasLength(17));
    final icu = const PatientFilter().toggleDepartment('ICU');
    expect(visiblePatients(snap, icu, ''), hasLength(8));
    expect(icu.toggleDepartment('ICU').isEmpty, isTrue);
    const old = PatientFilter(minAge: 80);
    expect(visiblePatients(snap, old, '').every((p) => p.age >= 80), isTrue);
    expect(old.activeCount, 1);
    expect(
      const PatientFilter(departments: {'ICU'}),
      const PatientFilter(departments: {'ICU'}),
    );
  });

  test('floor labels', () {
    expect(floorLabel(0), 'Ground floor');
    expect(floorLabel(2), 'Floor 2');
  });
}

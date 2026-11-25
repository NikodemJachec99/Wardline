// Local search, filters and department grouping for the Patients list
// (screens.md: Patients, Filters). Pure Dart so it is easy to test and the
// filters sheet can show a live "Show N patients" count.

import 'package:flutter/foundation.dart';

import '../../../data/hospital_repository.dart';
import '../../../domain/models.dart';

/// Age range slider bounds (Filters sheet, artboard `PatientsList` 6).
const int kAgeMin = 0;
const int kAgeMax = 100;

@immutable
class PatientFilter {
  const PatientFilter({
    this.statuses = const {},
    this.departments = const {},
    this.minAge = kAgeMin,
    this.maxAge = kAgeMax,
  });

  final Set<PatientStatus> statuses;

  /// Department codes.
  final Set<String> departments;
  final int minAge;
  final int maxAge;

  bool get ageActive => minAge > kAgeMin || maxAge < kAgeMax;

  /// Number of filter groups in use (badge on the filter button).
  int get activeCount =>
      (statuses.isNotEmpty ? 1 : 0) +
      (departments.isNotEmpty ? 1 : 0) +
      (ageActive ? 1 : 0);

  bool get isEmpty => activeCount == 0;

  bool matches(Patient p) =>
      (statuses.isEmpty || statuses.contains(p.status)) &&
      (departments.isEmpty || departments.contains(p.location)) &&
      p.age >= minAge &&
      p.age <= maxAge;

  PatientFilter copyWith({
    Set<PatientStatus>? statuses,
    Set<String>? departments,
    int? minAge,
    int? maxAge,
  }) => PatientFilter(
    statuses: statuses ?? this.statuses,
    departments: departments ?? this.departments,
    minAge: minAge ?? this.minAge,
    maxAge: maxAge ?? this.maxAge,
  );

  PatientFilter toggleStatus(PatientStatus s) => copyWith(
    statuses: statuses.contains(s)
        ? ({...statuses}..remove(s))
        : {...statuses, s},
  );

  PatientFilter toggleDepartment(String code) => copyWith(
    departments: departments.contains(code)
        ? ({...departments}..remove(code))
        : {...departments, code},
  );

  @override
  bool operator ==(Object other) =>
      other is PatientFilter &&
      setEquals(other.statuses, statuses) &&
      setEquals(other.departments, departments) &&
      other.minAge == minAge &&
      other.maxAge == maxAge;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(statuses),
    Object.hashAllUnordered(departments),
    minAge,
    maxAge,
  );
}

/// Lower case without Polish diacritics, so "zajac" finds "Zając".
String foldForSearch(String s) {
  const from = 'ąćęłńóśźż';
  const to = 'acelnoszz';
  final lower = s.toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

/// Search runs locally on name, patient ID and department (name, short
/// name, code). IDs also match without the dash ("HPT7K3M").
bool matchesQuery(Patient p, Department? d, String query) {
  final q = foldForSearch(query.trim());
  if (q.isEmpty) return true;
  final fields = <String>[
    p.fullName,
    p.code,
    p.code.replaceAll('-', ''),
    if (d != null) ...[d.name, d.shortName, d.code],
  ];
  return fields.any((f) => foldForSearch(f).contains(q));
}

int _byName(Patient a, Patient b) {
  final last = a.lastName.compareTo(b.lastName);
  return last != 0 ? last : a.firstName.compareTo(b.firstName);
}

/// Patients matching [filter] and [query].
List<Patient> visiblePatients(
  HospitalSnapshot s,
  PatientFilter filter,
  String query,
) => s.patients
    .where(
      (p) =>
          filter.matches(p) && matchesQuery(p, s.department(p.location), query),
    )
    .toList();

@immutable
class PatientGroup {
  const PatientGroup(this.department, this.patients);

  final Department department;

  /// Sorted by last name.
  final List<Patient> patients;
}

/// Groups in the hospital's department order; empty groups are left out.
List<PatientGroup> groupByDepartment(
  HospitalSnapshot s,
  List<Patient> patients,
) {
  final groups = <PatientGroup>[];
  for (final d in s.departments) {
    final inDept = patients.where((p) => p.location == d.code).toList()
      ..sort(_byName);
    if (inDept.isNotEmpty) groups.add(PatientGroup(d, inDept));
  }
  return groups;
}

/// "Ground floor" / "Floor 1" (sample-data.json floors).
String floorLabel(int floor) => floor == 0 ? 'Ground floor' : 'Floor $floor';

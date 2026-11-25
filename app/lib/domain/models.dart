// Domain models. Mirror docs/PLAN.md §5.1 (profiles, locations, patients,
// location_history, status_history). SIMULATION ONLY: fictional data.

import 'package:flutter/foundation.dart';

import '../core/theme/wl_tokens.dart';

export '../core/theme/wl_tokens.dart' show PatientStatus, UserRole;

enum DepartmentKind { emergency, ward, diagnostic, lab, surgery, icu, other }

/// Floor-plan rectangle in map units (10 × 6 per floor, design sample data).
@immutable
class MapRect {
  const MapRect(this.x, this.y, this.w, this.d);

  final double x;
  final double y;
  final double w;
  final double d;
}

/// A hospital department (`locations` table).
@immutable
class Department {
  const Department({
    required this.code,
    required this.name,
    required this.kind,
    required this.floor,
    required this.beds,
    required this.map,
    String? shortName,
  }) : shortName = shortName ?? name;

  final String code;
  final String name;
  final String shortName;
  final DepartmentKind kind;
  final int floor;
  final int beds;
  final MapRect map;
}

/// A signed-in member of staff (`profiles`).
@immutable
class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.homeDepartment,
    this.shiftLabel,
  });

  final String id;
  final String name;
  final UserRole role;
  final String? email;
  final String? homeDepartment;
  final String? shiftLabel;

  String get roleLabel => switch (role) {
    UserRole.nurse => 'Nurse',
    UserRole.doctor => 'Doctor',
    UserRole.admin => 'Admin',
  };

  /// "Dr Piotr Zając" → "Zając"; "Anna Nowak" → "Anna".
  String get greetingName => role == UserRole.doctor
      ? 'Dr ${name.split(' ').last}'
      : name.split(' ').first;
}

@immutable
class Patient {
  const Patient({
    required this.id,
    required this.code,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.condition,
    required this.admittedAt,
    required this.location,
    required this.locationSince,
    required this.status,
    required this.statusSince,
    required this.version,
    this.locationBy,
  });

  final String id;

  /// HPT-XXXXXXXX (docs/ID_FORMAT.md).
  final String code;
  final String firstName;
  final String lastName;
  final int age;
  final String condition;
  final DateTime admittedAt;

  /// Department code.
  final String location;
  final DateTime locationSince;
  final String? locationBy;
  final PatientStatus status;
  final DateTime statusSince;

  /// Shared optimistic-lock version for location and status (PLAN §5.3).
  final int version;

  String get fullName => '$firstName $lastName';

  Patient copyWith({
    String? location,
    DateTime? locationSince,
    String? locationBy,
    PatientStatus? status,
    DateTime? statusSince,
    int? version,
  }) {
    return Patient(
      id: id,
      code: code,
      firstName: firstName,
      lastName: lastName,
      age: age,
      condition: condition,
      admittedAt: admittedAt,
      location: location ?? this.location,
      locationSince: locationSince ?? this.locationSince,
      locationBy: locationBy ?? this.locationBy,
      status: status ?? this.status,
      statusSince: statusSince ?? this.statusSince,
      version: version ?? this.version,
    );
  }
}

/// One entry of `location_history` ∪ `status_history`.
@immutable
sealed class HistoryEvent {
  const HistoryEvent({
    required this.id,
    required this.patientId,
    required this.at,
    required this.byName,
    required this.byRole,
  });

  final String id;
  final String patientId;

  /// Server time.
  final DateTime at;
  final String byName;
  final UserRole byRole;
}

/// Transfer, or admission when [from] is null.
final class LocationEvent extends HistoryEvent {
  const LocationEvent({
    required super.id,
    required super.patientId,
    required super.at,
    required super.byName,
    required super.byRole,
    required this.to,
    this.from,
    this.identifiedBy,
  });

  final String? from;
  final String to;

  /// "NFC", "QR" or "Search" (how the nurse opened the record).
  final String? identifiedBy;

  bool get isAdmission => from == null;
}

final class StatusEvent extends HistoryEvent {
  const StatusEvent({
    required super.id,
    required super.patientId,
    required super.at,
    required super.byName,
    required super.byRole,
    required this.from,
    required this.to,
    this.reason,
  });

  final PatientStatus? from;
  final PatientStatus to;
  final String? reason;
}

extension PatientStatusX on PatientStatus {
  /// Postgres enum value.
  String get dbName => switch (this) {
    PatientStatus.admitted => 'admitted',
    PatientStatus.inTreatment => 'in_treatment',
    PatientStatus.readyForDischarge => 'ready_for_discharge',
    PatientStatus.discharged => 'discharged',
  };

  static PatientStatus parse(String value) => PatientStatus.values.firstWhere(
    (s) => s.dbName == value,
    orElse: () => throw FormatException('Unknown status $value'),
  );
}

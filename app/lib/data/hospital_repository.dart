import '../domain/models.dart';

/// Everything the app reads about the hospital at one moment.
class HospitalSnapshot {
  const HospitalSnapshot({
    required this.departments,
    required this.staff,
    required this.patients,
    required this.events,
    required this.syncedAt,
    this.lastRemoteEvent,
  });

  final List<Department> departments;
  final List<StaffMember> staff;
  final List<Patient> patients;

  /// Newest first.
  final List<HistoryEvent> events;

  /// When this data was last confirmed by the server.
  final DateTime syncedAt;

  /// The most recent change made by someone else (realtime). Screens use it
  /// for the live highlight and the "moved by" toast.
  final HistoryEvent? lastRemoteEvent;

  Department? department(String code) {
    for (final d in departments) {
      if (d.code == code) return d;
    }
    return null;
  }

  Patient? patient(String id) {
    for (final p in patients) {
      if (p.id == id) return p;
    }
    return null;
  }

  StaffMember? staffByName(String name) {
    for (final s in staff) {
      if (s.name == name) return s;
    }
    return null;
  }

  /// Patients currently in a department (discharged ones excluded).
  int occupancy(String code) => patients
      .where((p) => p.location == code && p.status != PatientStatus.discharged)
      .length;

  List<HistoryEvent> historyFor(String patientId) =>
      events.where((e) => e.patientId == patientId).toList();
}

/// Read/write contract. The demo implementation lives in
/// data/demo/demo_hospital_repository.dart; the Supabase one (issue #16)
/// calls the RPCs from docs/PLAN.md §5.3 with the same arguments.
abstract interface class HospitalRepository {
  HospitalSnapshot get current;

  /// Emits a new snapshot on every change (own write, realtime, refetch).
  Stream<HospitalSnapshot> watch();

  /// Read only. Scanning never writes.
  Future<Patient?> findByCode(String code);

  /// RPC `transfer_patient(p_patient_id, p_to, p_expected_version,
  /// p_request_id)`. Throws a WlFailure.
  Future<LocationEvent> transferPatient({
    required String patientId,
    required String to,
    required int expectedVersion,
    required String requestId,
    required StaffMember by,
    String? identifiedBy,
  });

  /// RPC `set_patient_status(…, p_reason)`. Throws a WlFailure.
  Future<StatusEvent> setPatientStatus({
    required String patientId,
    required PatientStatus status,
    required int expectedVersion,
    required String requestId,
    required StaffMember by,
    String? reason,
  });

  /// Full refetch (after reconnect: Realtime does not replay missed events).
  Future<void> refresh();

  void dispose();
}

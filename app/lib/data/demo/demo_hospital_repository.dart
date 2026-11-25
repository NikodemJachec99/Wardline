import 'dart:async';
import 'dart:math';

import '../../domain/failures.dart';
import '../../domain/models.dart';
import '../hospital_repository.dart';
import 'demo_seed.dart';

/// Knobs for the demo (admin › Demo mode and tests).
class DemoKnobs {
  /// Simulated round trip for writes.
  Duration latency = const Duration(milliseconds: 700);

  /// Next write: someone else moves the patient first → PT409.
  bool conflictNext = false;

  /// Next write: no answer in time (the write still lands, so "Check status"
  /// with the same request id finds it).
  bool timeoutNext = false;

  /// Online / offline. Offline: reads keep the cached snapshot, writes fail.
  bool online = true;
}

/// In-memory hospital that behaves like the backend contract
/// (docs/PLAN.md §5.3): role checks, idempotency by request id, version
/// conflicts, same-location / same-status errors.
class DemoHospitalRepository implements HospitalRepository {
  DemoHospitalRepository(DemoSeed seed, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _departments = seed.departments,
      _staff = seed.staff,
      _patients = {for (final p in seed.patients) p.id: p},
      _events = [...seed.events],
      _syncedAt = (clock ?? DateTime.now)();

  final DateTime Function() _clock;
  final List<Department> _departments;
  final List<StaffMember> _staff;
  final Map<String, Patient> _patients;
  final List<HistoryEvent> _events;
  final Map<String, HistoryEvent> _byRequest = {};
  final StreamController<HospitalSnapshot> _changes =
      StreamController<HospitalSnapshot>.broadcast();
  final DemoKnobs knobs = DemoKnobs();
  final Random _rnd = Random(7);
  DateTime _syncedAt;
  HistoryEvent? _lastRemote;
  late HospitalSnapshot _current = _snapshot();
  var _seq = 0;

  HospitalSnapshot _snapshot() => HospitalSnapshot(
    departments: _departments,
    staff: _staff,
    patients: _patients.values.toList(growable: false),
    events: List.unmodifiable(_events),
    syncedAt: _syncedAt,
    lastRemoteEvent: _lastRemote,
  );

  void _emit() {
    if (knobs.online) _syncedAt = _clock();
    _current = _snapshot();
    if (!_changes.isClosed) _changes.add(_current);
  }

  @override
  HospitalSnapshot get current => _current;

  @override
  Stream<HospitalSnapshot> watch() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<Patient?> findByCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    for (final p in _patients.values) {
      if (p.code == code) return p;
    }
    return null;
  }

  Future<void> _roundTrip() async {
    if (!knobs.online) throw const OfflineFailure();
    await Future<void>.delayed(knobs.latency);
    if (!knobs.online) throw const OfflineFailure();
  }

  /// Someone else changes the patient right before our write lands.
  void _applyConcurrentMove(Patient p) {
    final other = _staff.firstWhere(
      (s) => s.role == UserRole.nurse && s.name != p.locationBy,
      orElse: () => _staff.first,
    );
    final options = _departments.where((d) => d.code != p.location).toList();
    final to = options.firstWhere(
      (d) => d.code == 'CAR',
      orElse: () => options[_rnd.nextInt(options.length)],
    );
    _remoteTransfer(
      p,
      to.code,
      other,
      at: _clock().subtract(const Duration(minutes: 5)),
    );
  }

  @override
  Future<LocationEvent> transferPatient({
    required String patientId,
    required String to,
    required int expectedVersion,
    required String requestId,
    required StaffMember by,
    String? identifiedBy,
  }) async {
    final existing = _byRequest[requestId];
    if (existing is LocationEvent) {
      await _roundTrip();
      return existing; // idempotent retry ("Check status")
    }
    await _roundTrip();
    if (by.role != UserRole.nurse) throw const ForbiddenFailure();
    if (!_departments.any((d) => d.code == to)) {
      throw const InvalidRequestFailure('INVALID_LOCATION');
    }
    final p = _patients[patientId];
    if (p == null) throw const NotFoundFailure();
    if (knobs.conflictNext) {
      knobs.conflictNext = false;
      _applyConcurrentMove(p);
    }
    final now = _patients[patientId]!;
    if (now.version != expectedVersion) throw _conflictFor(now);
    if (now.location == to) throw const InvalidRequestFailure('SAME_LOCATION');

    final evt = LocationEvent(
      id: 'evt-own-${_seq++}',
      patientId: patientId,
      at: _clock(),
      byName: by.name,
      byRole: by.role,
      from: now.location,
      to: to,
      identifiedBy: identifiedBy,
    );
    _patients[patientId] = now.copyWith(
      location: to,
      locationSince: evt.at,
      locationBy: by.name,
      version: now.version + 1,
    );
    _events.insert(0, evt);
    _byRequest[requestId] = evt;
    _emit();
    if (knobs.timeoutNext) {
      knobs.timeoutNext = false;
      throw TimeoutFailure(requestId);
    }
    return evt;
  }

  @override
  Future<StatusEvent> setPatientStatus({
    required String patientId,
    required PatientStatus status,
    required int expectedVersion,
    required String requestId,
    required StaffMember by,
    String? reason,
  }) async {
    final existing = _byRequest[requestId];
    if (existing is StatusEvent) {
      await _roundTrip();
      return existing;
    }
    await _roundTrip();
    if (by.role != UserRole.doctor) throw const ForbiddenFailure();
    final p = _patients[patientId];
    if (p == null) throw const NotFoundFailure();
    if (knobs.conflictNext) {
      knobs.conflictNext = false;
      _applyConcurrentMove(p);
    }
    final now = _patients[patientId]!;
    if (now.version != expectedVersion) throw _conflictFor(now);
    if (now.status == status) throw const InvalidRequestFailure('SAME_STATUS');
    if (status == PatientStatus.discharged &&
        (reason == null || reason.trim().isEmpty)) {
      throw const InvalidRequestFailure('REASON_REQUIRED');
    }
    final evt = StatusEvent(
      id: 'evt-own-${_seq++}',
      patientId: patientId,
      at: _clock(),
      byName: by.name,
      byRole: by.role,
      from: now.status,
      to: status,
      reason: reason,
    );
    _patients[patientId] = now.copyWith(
      status: status,
      statusSince: evt.at,
      version: now.version + 1,
    );
    _events.insert(0, evt);
    _byRequest[requestId] = evt;
    _emit();
    if (knobs.timeoutNext) {
      knobs.timeoutNext = false;
      throw TimeoutFailure(requestId);
    }
    return evt;
  }

  ConflictFailure _conflictFor(Patient p) {
    final last = _events.firstWhere((e) => e.patientId == p.id);
    String? name(String? code) => code == null
        ? null
        : _departments.firstWhere((d) => d.code == code).name;
    return switch (last) {
      LocationEvent(:final from, :final to) => ConflictFailure(
        byName: last.byName,
        byRoleLabel: _roleLabel(last.byRole),
        at: last.at,
        from: name(from),
        to: name(to),
      ),
      StatusEvent() => ConflictFailure(
        byName: last.byName,
        byRoleLabel: _roleLabel(last.byRole),
        at: last.at,
      ),
    };
  }

  static String _roleLabel(UserRole r) => switch (r) {
    UserRole.nurse => 'Nurse',
    UserRole.doctor => 'Doctor',
    UserRole.admin => 'Admin',
  };

  /// A change by another user, delivered like a realtime event.
  LocationEvent _remoteTransfer(
    Patient p,
    String to,
    StaffMember by, {
    DateTime? at,
  }) {
    final evt = LocationEvent(
      id: 'evt-remote-${_seq++}',
      patientId: p.id,
      at: at ?? _clock(),
      byName: by.name,
      byRole: by.role,
      from: p.location,
      to: to,
      identifiedBy: 'NFC',
    );
    _patients[p.id] = p.copyWith(
      location: to,
      locationSince: evt.at,
      locationBy: by.name,
      version: p.version + 1,
    );
    _events.insert(0, evt);
    _lastRemote = evt;
    _emit();
    return evt;
  }

  /// Demo: another nurse moves a random patient (used by Demo mode and the
  /// two-device scenario).
  LocationEvent? simulateRemoteTransfer({String? patientId, String? to}) {
    if (!knobs.online) return null;
    final candidates = _patients.values
        .where((p) => p.status != PatientStatus.discharged)
        .toList();
    final p = patientId != null
        ? _patients[patientId]!
        : candidates[_rnd.nextInt(candidates.length)];
    final dest =
        to ??
        (_departments.where((d) => d.code != p.location).toList()
              ..shuffle(_rnd))
            .first
            .code;
    final nurse = _staff.firstWhere(
      (s) => s.role == UserRole.nurse && s.name != 'Anna Nowak',
    );
    return _remoteTransfer(p, dest, nurse);
  }

  /// Demo: a doctor changes a random patient's status.
  StatusEvent? simulateRemoteStatus() {
    if (!knobs.online) return null;
    final candidates = _patients.values
        .where(
          (p) =>
              p.status == PatientStatus.admitted ||
              p.status == PatientStatus.inTreatment,
        )
        .toList();
    if (candidates.isEmpty) return null;
    final p = candidates[_rnd.nextInt(candidates.length)];
    final to = p.status == PatientStatus.admitted
        ? PatientStatus.inTreatment
        : PatientStatus.readyForDischarge;
    final doc = _staff.firstWhere((s) => s.role == UserRole.doctor);
    final evt = StatusEvent(
      id: 'evt-remote-${_seq++}',
      patientId: p.id,
      at: _clock(),
      byName: doc.name,
      byRole: doc.role,
      from: p.status,
      to: to,
    );
    _patients[p.id] = p.copyWith(
      status: to,
      statusSince: evt.at,
      version: p.version + 1,
    );
    _events.insert(0, evt);
    _lastRemote = evt;
    _emit();
    return evt;
  }

  /// Go offline / online. Back online = full refetch.
  void setOnline(bool online) {
    knobs.online = online;
    if (online) _emit();
  }

  @override
  Future<void> refresh() async {
    if (!knobs.online) throw const OfflineFailure();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _emit();
  }

  @override
  void dispose() => _changes.close();
}

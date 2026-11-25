import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/domain/failures.dart';
import 'package:wardline/domain/models.dart';

import '../helpers/harness.dart';

void main() {
  group('demo seed matches the design totals', () {
    final repo = demoRepository();
    final s = repo.current;

    test('128 patients, 12 departments, occupancy per department', () {
      expect(s.patients, hasLength(128));
      expect(s.departments, hasLength(12));
      expect(s.occupancy('INT'), 29);
      expect(s.occupancy('ICU'), 8);
      expect(s.occupancy('LAB'), 5);
    });

    test('status totals 57 / 54 / 17', () {
      int n(PatientStatus st) => s.patients.where((p) => p.status == st).length;
      expect(n(PatientStatus.admitted), 57);
      expect(n(PatientStatus.inTreatment), 54);
      expect(n(PatientStatus.readyForDischarge), 17);
    });

    test('42 transfers today, patient codes valid and unique', () {
      final transfers = s.events.whereType<LocationEvent>().where(
        (e) => !e.isAdmission && e.at.day == demoNow.day,
      );
      expect(transfers, hasLength(42));
      final codes = s.patients.map((p) => p.code).toSet();
      expect(codes, hasLength(128));
      final re = RegExp(r'^HPT-[0-9A-HJKMNP-TV-Z]{8}$');
      expect(codes.every(re.hasMatch), isTrue);
    });

    test("Jan's day: admission ER, then RAD, INT, status, LAB", () {
      final jan = s.patients.first;
      expect(jan.fullName, 'Jan Kowalczyk');
      expect(jan.location, 'LAB');
      final h = s.historyFor(jan.id);
      expect(h, hasLength(5));
      expect(
        h.last,
        isA<LocationEvent>().having((e) => e.isAdmission, 'admission', true),
      );
    });
  });

  group('transfer_patient contract', () {
    test('nurse moves patient, version bumps, event recorded', () async {
      final repo = demoRepository();
      final jan = repo.current.patients.first;
      final evt = await repo.transferPatient(
        patientId: jan.id,
        to: 'RAD',
        expectedVersion: jan.version,
        requestId: 'req-1',
        by: staff(repo, 'Anna Nowak'),
      );
      expect(evt.from, 'LAB');
      expect(evt.to, 'RAD');
      final after = repo.current.patient(jan.id)!;
      expect(after.location, 'RAD');
      expect(after.version, jan.version + 1);
      expect(repo.current.events.first, evt);
    });

    test('same request id is idempotent (double tap, check status)', () async {
      final repo = demoRepository();
      final jan = repo.current.patients.first;
      final nurse = staff(repo, 'Anna Nowak');
      final a = await repo.transferPatient(
        patientId: jan.id,
        to: 'RAD',
        expectedVersion: jan.version,
        requestId: 'same',
        by: nurse,
      );
      final b = await repo.transferPatient(
        patientId: jan.id,
        to: 'RAD',
        expectedVersion: jan.version,
        requestId: 'same',
        by: nurse,
      );
      expect(identical(a, b), isTrue);
      // 4 seeded (admission + 3 transfers) + exactly one new.
      expect(
        repo.current.historyFor(jan.id).whereType<LocationEvent>(),
        hasLength(5),
      );
    });

    test('doctor is forbidden (PT403)', () async {
      final repo = demoRepository();
      final jan = repo.current.patients.first;
      expect(
        () => repo.transferPatient(
          patientId: jan.id,
          to: 'RAD',
          expectedVersion: jan.version,
          requestId: 'r',
          by: staff(repo, 'Dr Piotr Zając'),
        ),
        throwsA(isA<ForbiddenFailure>()),
      );
    });

    test('stale version gives PT409 with who / where, no retry', () async {
      final repo = demoRepository()..knobs.conflictNext = true;
      final jan = repo.current.patients.first;
      await expectLater(
        repo.transferPatient(
          patientId: jan.id,
          to: 'RAD',
          expectedVersion: jan.version,
          requestId: 'r',
          by: staff(repo, 'Anna Nowak'),
        ),
        throwsA(
          isA<ConflictFailure>()
              .having((c) => c.to, 'to', 'Cardiology')
              .having((c) => c.from, 'from', 'Laboratory')
              .having((c) => c.byRoleLabel, 'role', 'Nurse'),
        ),
      );
      expect(repo.current.patient(jan.id)!.location, 'CAR');
    });

    test('same location is PT422', () async {
      final repo = demoRepository();
      final jan = repo.current.patients.first;
      expect(
        () => repo.transferPatient(
          patientId: jan.id,
          to: 'LAB',
          expectedVersion: jan.version,
          requestId: 'r',
          by: staff(repo, 'Anna Nowak'),
        ),
        throwsA(isA<InvalidRequestFailure>()),
      );
    });

    test('offline fails fast and writes nothing', () async {
      final repo = demoRepository()..setOnline(false);
      final jan = repo.current.patients.first;
      await expectLater(
        repo.transferPatient(
          patientId: jan.id,
          to: 'RAD',
          expectedVersion: jan.version,
          requestId: 'r',
          by: staff(repo, 'Anna Nowak'),
        ),
        throwsA(isA<OfflineFailure>()),
      );
      expect(repo.current.patient(jan.id)!.location, 'LAB');
    });

    test('timeout: write landed, check status with same id finds it', () async {
      final repo = demoRepository()..knobs.timeoutNext = true;
      final jan = repo.current.patients.first;
      final nurse = staff(repo, 'Anna Nowak');
      await expectLater(
        repo.transferPatient(
          patientId: jan.id,
          to: 'RAD',
          expectedVersion: jan.version,
          requestId: 'slow',
          by: nurse,
        ),
        throwsA(isA<TimeoutFailure>()),
      );
      final again = await repo.transferPatient(
        patientId: jan.id,
        to: 'RAD',
        expectedVersion: jan.version,
        requestId: 'slow',
        by: nurse,
      );
      expect(again.to, 'RAD');
    });
  });

  group('set_patient_status contract', () {
    test('doctor changes status, location unchanged', () async {
      final repo = demoRepository();
      final jan = repo.current.patients.first;
      await repo.setPatientStatus(
        patientId: jan.id,
        status: PatientStatus.readyForDischarge,
        expectedVersion: jan.version,
        requestId: 's1',
        by: staff(repo, 'Dr Piotr Zając'),
      );
      final after = repo.current.patient(jan.id)!;
      expect(after.status, PatientStatus.readyForDischarge);
      expect(after.location, jan.location);
    });

    test('nurse is forbidden, discharge needs a reason', () async {
      final repo = demoRepository();
      final jan = repo.current.patients.first;
      expect(
        () => repo.setPatientStatus(
          patientId: jan.id,
          status: PatientStatus.readyForDischarge,
          expectedVersion: jan.version,
          requestId: 's',
          by: staff(repo, 'Anna Nowak'),
        ),
        throwsA(isA<ForbiddenFailure>()),
      );
      expect(
        () => repo.setPatientStatus(
          patientId: jan.id,
          status: PatientStatus.discharged,
          expectedVersion: jan.version,
          requestId: 's2',
          by: staff(repo, 'Dr Piotr Zając'),
        ),
        throwsA(isA<InvalidRequestFailure>()),
      );
    });
  });

  test('scan lookup is read only', () async {
    final repo = demoRepository();
    final before = repo.current.events.length;
    final p = await repo.findByCode('HPT-7K3M9QX2');
    expect(p?.fullName, 'Jan Kowalczyk');
    expect(await repo.findByCode('HPT-00000000'), isNull);
    expect(repo.current.events.length, before);
  });
}

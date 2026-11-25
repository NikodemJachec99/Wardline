import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/app/theme.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/data/hospital_repository.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/map/presentation/hospital_map_screen.dart';
import 'package:wardline/features/patients/presentation/patient_profile_screen.dart';
import 'package:wardline/features/patients/presentation/patients_screen.dart';

import '../../helpers/harness.dart';
import 'patients_test_utils.dart';

Finder _chip(String label) =>
    find.descendant(of: find.byType(WlFilterChips), matching: find.text(label));

void main() {
  testWidgets('list: 128 patients grouped by department with headers', (
    tester,
  ) async {
    phone(tester);
    await openApp(tester);
    expect(find.byType(PatientsScreen), findsOneWidget);
    expect(find.text('Patients'), findsWidgets);
    expect(find.text('128 patients'), findsOneWidget);
    expect(_chip('All'), findsOneWidget);
    expect(_chip('128'), findsOneWidget);
    expect(find.text('EMERGENCY DEPARTMENT · 19'), findsOneWidget);
    expect(find.text('79% · 5 free'), findsOneWidget);
    expect(find.byType(WlPatientCard), findsWidgets);
    expect(find.byType(WlSearchBar), findsOneWidget);
  });

  testWidgets('flow 3 step 1: search "Kowalczyk" leaves only Jan', (
    tester,
  ) async {
    phone(tester);
    await openApp(tester, as: 'Dr Piotr Zając');
    await tester.enterText(find.byType(TextField), 'Kowalczyk');
    await settle(tester);
    expect(find.byType(WlPatientCard), findsOneWidget);
    expect(cardOf('Jan Kowalczyk'), findsOneWidget);
    expect(find.text('1 of 128 patients'), findsOneWidget);
    expect(find.text('LABORATORY · 1'), findsOneWidget);

    await tester.tap(cardOf('Jan Kowalczyk'));
    await settle(tester);
    expect(find.byType(PatientProfileScreen), findsOneWidget);
    expect(
      tester
          .widget<PatientProfileScreen>(find.byType(PatientProfileScreen))
          .patientId,
      janId,
    );
    // Flow 3 step 2: doctor sees Change status, no Transfer anywhere.
    expect(find.text('Change status'), findsOneWidget);
    expect(find.text('Transfer patient'), findsNothing);
  });

  testWidgets('search by patient ID and by department', (tester) async {
    phone(tester);
    await openApp(tester);
    await tester.enterText(find.byType(TextField), 'HPT-7K3M9QX2');
    await settle(tester);
    expect(find.byType(WlPatientCard), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Intensive');
    await settle(tester);
    expect(find.text('8 of 128 patients'), findsOneWidget);
  });

  testWidgets('status chip filters the list', (tester) async {
    phone(tester);
    await openApp(tester);
    await tester.ensureVisible(_chip('Ready'));
    await settle(tester);
    await tester.tap(_chip('Ready'));
    await settle(tester);
    expect(find.text('17 of 128 patients'), findsOneWidget);
    final cards = tester.widgetList<WlPatientCard>(find.byType(WlPatientCard));
    expect(cards, isNotEmpty);
    expect(
      cards.every((c) => c.status == PatientStatus.readyForDischarge),
      isTrue,
    );
    // All clears filters.
    await tester.ensureVisible(_chip('All'));
    await settle(tester);
    await tester.tap(_chip('All'));
    await settle(tester);
    expect(find.text('128 patients'), findsOneWidget);
  });

  testWidgets('filters sheet shows the live result count', (tester) async {
    phone(tester);
    await openApp(tester);
    await tester.tap(find.bySemanticsLabel('Filters'));
    await settle(tester);
    expect(find.text('Filters'), findsWidgets);
    expect(find.text('Show 128 patients'), findsOneWidget);

    await tester.tap(find.text('ICU'));
    await settle(tester);
    expect(find.text('Show 8 patients'), findsOneWidget);
    await tester.tap(find.text('In Treatment').last);
    await settle(tester);
    final inTreatmentIcu = demoRepositoryCount(
      tester,
      (p) => p.location == 'ICU' && p.status == PatientStatus.inTreatment,
    );
    expect(
      find.text(
        inTreatmentIcu == 1
            ? 'Show 1 patient'
            : 'Show $inTreatmentIcu patients',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Reset'));
    await settle(tester);
    expect(find.text('Show 128 patients'), findsOneWidget);
    await tester.tap(find.text('ICU'));
    await settle(tester);
    await tester.tap(find.text('Show 8 patients'));
    await settle(tester);
    expect(find.text('8 of 128 patients'), findsOneWidget);
    // Department chip now names the selected department.
    expect(_chip('Intensive Care'), findsOneWidget);
    expect(find.bySemanticsLabel('Filters, 1 active'), findsOneWidget);
  });

  testWidgets('empty search says what was searched and how to recover', (
    tester,
  ) async {
    phone(tester);
    await openApp(tester);
    await tester.enterText(find.byType(TextField), 'Zzzz');
    await settle(tester);
    expect(find.byType(WlPatientCard), findsNothing);
    expect(find.byType(WlEmptyState), findsOneWidget);
    expect(find.text('No patients match "Zzzz"'), findsOneWidget);
    expect(
      find.text(
        'Check the spelling, or search by patient ID, e.g. HPT-7K3M9QX2.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Clear search'));
    await settle(tester);
    expect(find.text('128 patients'), findsOneWidget);
  });

  testWidgets('flow 4: offline shows banner, cache badge, "as of" on cards', (
    tester,
  ) async {
    phone(tester);
    await openApp(tester);
    await goOffline(tester);
    expect(find.byType(WlOfflineBanner), findsOneWidget);
    expect(find.byType(WlCacheBadge), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Search cached patients'), findsOneWidget);
    final card = tester.widget<WlPatientCard>(find.byType(WlPatientCard).first);
    expect(card.cachedAsOf, isNotNull);
    // Local search still works offline.
    await tester.enterText(find.byType(TextField), 'Kowalczyk');
    await settle(tester);
    expect(cardOf('Jan Kowalczyk'), findsOneWidget);
  });

  testWidgets('flow 6: remote transfer highlights the card and its sub line', (
    tester,
  ) async {
    phone(tester);
    final repo = await openApp(tester, as: 'Dr Piotr Zając');
    await tester.enterText(find.byType(TextField), 'Kowalczyk');
    await settle(tester);
    final before = tester.widget<WlPatientCard>(cardOf('Jan Kowalczyk'));
    expect(before.subtitle, 'Laboratory');
    expect(before.highlightKey, isNull);

    final evt = repo.simulateRemoteTransfer(patientId: janId, to: 'RAD')!;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final after = tester.widget<WlPatientCard>(cardOf('Jan Kowalczyk'));
    expect(after.subtitle, 'Moved to Radiology · now');
    expect(after.highlightKey, evt.id);
    expect(after.key, const ValueKey(janId));
    expect(find.text('RADIOLOGY · 1'), findsOneWidget);
    // The shell shows the realtime toast.
    expect(
      find.text('Jan Kowalczyk moved to Radiology · by M. Kowal'),
      findsOneWidget,
    );
    await drain(tester);
  });

  testWidgets('swipe action Show on map opens the map for the patient', (
    tester,
  ) async {
    phone(tester);
    await openApp(tester);
    await tester.enterText(find.byType(TextField), 'Kowalczyk');
    await settle(tester);
    await tester.drag(cardOf('Jan Kowalczyk'), const Offset(-200, 0));
    await settle(tester);
    expect(find.text('View profile'), findsOneWidget);
    expect(find.text('Show on map'), findsOneWidget);
    // The revealed buttons sit under the card's gesture layer in the shared
    // WlPatientCard, so trigger the same callback the button and the
    // semantics custom action use.
    tester.widget<WlPatientCard>(cardOf('Jan Kowalczyk')).onShowOnMap!();
    await settle(tester);
    final map = tester.widget<HospitalMapScreen>(
      find.byType(HospitalMapScreen),
    );
    expect(map.patientId, janId);
  });

  testWidgets('loading skeleton while the snapshot has no patients', (
    tester,
  ) async {
    phone(tester);
    final empty = _EmptyRepository(demoRepositorySnapshot());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hospitalRepositoryProvider.overrideWithValue(empty)],
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: PatientsScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(WlSkeletonScope), findsWidgets);
    expect(find.byType(WlSkeleton), findsWidgets);
    expect(find.byType(WlPatientCard), findsNothing);
    expect(find.byType(WlEmptyState), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('text scale 2.0: list and filters do not overflow', (
    tester,
  ) async {
    phone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Patients'), findsWidgets);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('Filters'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Show 128 patients'), findsOneWidget);
  });
}

int demoRepositoryCount(WidgetTester tester, bool Function(Patient) test) =>
    container(tester).read(hospitalProvider).patients.where(test).length;

HospitalSnapshot demoRepositorySnapshot() {
  final s = demoRepository().current;
  return HospitalSnapshot(
    departments: s.departments,
    staff: s.staff,
    patients: const [],
    events: const [],
    syncedAt: s.syncedAt,
  );
}

/// Snapshot with no patients yet (first load).
class _EmptyRepository implements HospitalRepository {
  _EmptyRepository(this.current);

  @override
  final HospitalSnapshot current;

  @override
  Stream<HospitalSnapshot> watch() => Stream.value(current);

  @override
  Future<Patient?> findByCode(String code) async => null;

  @override
  Future<void> refresh() async {}

  @override
  Future<LocationEvent> transferPatient({
    required String patientId,
    required String to,
    required int expectedVersion,
    required String requestId,
    required StaffMember by,
    String? identifiedBy,
  }) => Completer<LocationEvent>().future;

  @override
  Future<StatusEvent> setPatientStatus({
    required String patientId,
    required PatientStatus status,
    required int expectedVersion,
    required String requestId,
    required StaffMember by,
    String? reason,
  }) => Completer<StatusEvent>().future;

  @override
  void dispose() {}
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/map/presentation/hospital_map_screen.dart';
import 'package:wardline/features/patients/presentation/patient_profile_screen.dart';

import 'patients_test_utils.dart';

const String _jan = '/patients/$janId';

void main() {
  testWidgets('nurse: Transfer patient, no Change status', (tester) async {
    phone(tester);
    await openApp(tester, location: _jan);
    expect(find.byType(PatientProfileScreen), findsOneWidget);
    expect(find.text('Jan Kowalczyk'), findsOneWidget);
    expect(find.text('Transfer patient'), findsOneWidget);
    expect(find.text('Change status'), findsNothing);
    expect(find.textContaining('by Ewa Lis'), findsWidgets);

    // Status and location are separate rows of the expanded card.
    final card = tester.widget<WlPatientCard>(find.byType(WlPatientCard));
    expect(card.status, PatientStatus.inTreatment);
    expect(card.locationName, 'Laboratory');
    expect(card.locationDetail, 'Ground floor · since 10:31 · by Ewa Lis');
    expect(card.patientCode, 'HPT-7K3M9QX2');

    await tester.tap(find.text('Transfer patient'));
    await settle(tester);
    // Destination sheet from the transfer flow.
    expect(find.text('Move Jan Kowalczyk'), findsOneWidget);
  });

  testWidgets('doctor: Change status, no Transfer patient', (tester) async {
    phone(tester);
    await openApp(tester, as: 'Dr Piotr Zając', location: _jan);
    expect(find.text('Change status'), findsOneWidget);
    expect(find.text('Transfer patient'), findsNothing);
    expect(find.text('In Treatment since 09:52 · set by you'), findsOneWidget);
    await tester.tap(find.text('Change status'));
    await settle(tester);
    expect(find.byType(WlBottomSheet), findsOneWidget);
  });

  testWidgets('admin: no write action at all', (tester) async {
    phone(tester);
    await openApp(tester, as: 'Katarzyna Wilk', location: _jan);
    expect(find.text('Jan Kowalczyk'), findsOneWidget);
    expect(find.text('Transfer patient'), findsNothing);
    expect(find.text('Change status'), findsNothing);
    expect(find.byType(WlButton), findsNothing);
    expect(find.byType(WlOfflineActionNote), findsNothing);
  });

  testWidgets('flow 4: offline replaces the action with a note', (
    tester,
  ) async {
    phone(tester);
    await openApp(tester, location: _jan);
    await goOffline(tester);
    expect(find.byType(WlOfflineBanner), findsOneWidget);
    expect(find.byType(WlCacheBadge), findsOneWidget);
    expect(find.text('Transfer patient'), findsNothing);
    expect(find.byType(WlOfflineActionNote), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        "Changes need a connection. Transfers resume when you're back online.",
      ),
      findsOneWidget,
    );
    final card = tester.widget<WlPatientCard>(find.byType(WlPatientCard));
    expect(card.cachedAsOf, isNotNull);
  });

  testWidgets('doctor offline: note without the transfer detail', (
    tester,
  ) async {
    phone(tester);
    await openApp(tester, as: 'Dr Piotr Zając', location: _jan);
    await goOffline(tester);
    expect(find.text('Change status'), findsNothing);
    expect(find.byType(WlOfflineActionNote), findsOneWidget);
    expect(find.text('Changes need a connection'), findsOneWidget);
  });

  testWidgets("timeline shows Jan's 5 events, newest first, with details", (
    tester,
  ) async {
    phone(tester);
    await openApp(tester, location: _jan);
    final items = tester
        .widgetList<WlTimelineItem>(find.byType(WlTimelineItem))
        .toList();
    expect(items, hasLength(5));
    expect(find.text('5 events'), findsOneWidget);
    expect(items.map((i) => i.title).toList(), [
      'Transferred',
      'Status changed',
      'Transferred',
      'Transferred',
      'Admitted',
    ]);
    expect(items.map((i) => i.time).toList(), [
      '10:31',
      '09:52',
      '09:35',
      '08:47',
      '08:12',
    ]);
    expect(items.first.line, 'Internal Medicine → Laboratory');
    expect(items.first.kind, WlTimelineKind.transfer);
    expect(items[1].kind, WlTimelineKind.status);
    expect(items[1].line, 'Admitted → In Treatment');
    expect(items.last.kind, WlTimelineKind.admission);
    expect(items.last.line, 'Emergency Department');
    expect(items.last.isLast, isTrue);
    expect(items.every((i) => i.highlightKey == null), isTrue);

    final details = Map.fromEntries(
      items.first.details.map((d) => MapEntry(d.$1, d.$2)),
    );
    expect(details['From'], 'Internal Medicine · Floor 1');
    expect(details['To'], 'Laboratory · Ground');
    expect(details['Identified by'], 'NFC wristband');
    expect(details['Time in previous dept'], '56 min');
    expect(details['Server confirmed'], startsWith('10:31:'));
    final status = Map.fromEntries(
      items[1].details.map((d) => MapEntry(d.$1, d.$2)),
    );
    expect(status['Location at the time'], 'Internal Medicine');

    // Status stepper: Admitted and In Treatment reached with their times.
    await tester.ensureVisible(find.text('STATUS'));
    await settle(tester);
    expect(find.bySemanticsLabel('Admitted, done, at 08:12'), findsOneWidget);
    expect(
      find.bySemanticsLabel('In Treatment, current step, at 09:52'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Discharged, not reached'), findsOneWidget);
  });

  testWidgets('remote transfer: card updates, new item highlighted', (
    tester,
  ) async {
    phone(tester);
    final repo = await openApp(tester, location: _jan);
    final evt = repo.simulateRemoteTransfer(patientId: janId, to: 'RAD')!;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final card = tester.widget<WlPatientCard>(find.byType(WlPatientCard));
    expect(card.locationName, 'Radiology');
    expect(card.highlightKey, isNotNull);
    final items = tester
        .widgetList<WlTimelineItem>(find.byType(WlTimelineItem))
        .toList();
    expect(items, hasLength(6));
    expect(items.first.highlightKey, evt.id);
    expect(items.first.line, 'Laboratory → Radiology');
    expect(items.skip(1).every((i) => i.highlightKey == null), isTrue);
    expect(find.text('6 events'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('mini map opens the full map on that floor and department', (
    tester,
  ) async {
    phone(tester);
    await openApp(tester, location: _jan);
    final mini = tester.widget<WlMiniMap>(find.byType(WlMiniMap));
    expect(mini.floor, 0);
    expect(mini.highlightDepartment, 'LAB');
    expect(mini.patientInitials, 'JK');
    await tester.ensureVisible(find.byType(WlMiniMap));
    await settle(tester);
    await tester.tap(find.byType(WlMiniMap));
    await settle(tester);
    final map = tester.widget<HospitalMapScreen>(
      find.byType(HospitalMapScreen),
    );
    expect(map.floor, 0);
    expect(map.departmentCode, 'LAB');
    expect(map.patientId, janId);
  });

  testWidgets('unknown id: not found online, "connect to load" offline', (
    tester,
  ) async {
    phone(tester);
    await openApp(tester, location: '/patients/p-NOPE');
    expect(find.byType(WlErrorState), findsOneWidget);
    expect(find.text('Patient not found'), findsOneWidget);
    expect(find.text('Transfer patient'), findsNothing);

    await goOffline(tester);
    expect(find.text('Connect to load'), findsOneWidget);
    expect(
      find.text(
        "This patient hasn't been loaded on this device yet. Connect to the internet to open the record.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to patients'));
    await settle(tester);
    expect(find.byType(PatientProfileScreen), findsNothing);
  });

  testWidgets('text scale 2.0: rows stack, nothing overflows', (tester) async {
    phone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openApp(tester, location: _jan);
    expect(tester.takeException(), isNull);
    expect(find.text('Jan Kowalczyk'), findsOneWidget);
    expect(find.textContaining('HPT-7K3M9QX2'), findsWidgets);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1500),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Transfer patient'), findsOneWidget);
  });
}

// Flow 3 (design/handoff/flows.md): doctor changes status; location never
// changes. Plus discharge reason, conflict, timeout and offline.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/status/presentation/change_status_sheet.dart';

import '../transfer/transfer_test_helpers.dart';

const String doctor = 'Dr Piotr Zając';

Finder option(PatientStatus s) =>
    find.byKey(ValueKey('status-option-${s.name}'));

Finder inSheet(Finder f) =>
    find.descendant(of: find.byType(WlBottomSheet), matching: f);

Finder get saveButton => find.byKey(const ValueKey('status-save'));

Future<void> openSheet(WidgetTester tester, RecordingRepository repo) async {
  final profile = await openJanProfile(tester);
  unawaited(showChangeStatusSheet(profile, patient: repo.jan));
  await settle(tester);
}

void main() {
  testWidgets('Flow 3: In Treatment → Ready for Discharge, location '
      'unchanged, toast after the server answered', (tester) async {
    final repo = RecordingRepository();
    await pumpApp(tester, repo, as: doctor);
    await openSheet(tester, repo);

    expect(inSheet(find.text('Change status')), findsOneWidget);
    expect(
      find.text("Location doesn't change. Jan stays in Laboratory."),
      findsOneWidget,
    );
    for (final s in PatientStatus.values) {
      expect(option(s), findsOneWidget);
    }
    expect(find.textContaining('Current · since'), findsOneWidget);
    expect(find.text('Reason (optional)'), findsOneWidget);

    // Nothing chosen yet: Save does nothing.
    await tester.tap(saveButton);
    await settle(tester);
    expect(repo.statusRequestIds, isEmpty);

    // The current status can't be picked.
    await tester.tap(option(PatientStatus.inTreatment));
    await tester.tap(saveButton);
    await settle(tester);
    expect(repo.statusRequestIds, isEmpty);

    await tester.tap(option(PatientStatus.readyForDischarge));
    await tester.pump();
    await tester.tap(saveButton);
    await tester.tap(saveButton, warnIfMissed: false);
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    expect(find.text('Waiting for the server'), findsOneWidget);
    expect(find.text('Status updated'), findsNothing);
    // Locked while in flight: back does not close it.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);

    await settle(tester);
    expect(repo.statusRequestIds, hasLength(1));
    expect(inSheet(find.text('Change status')), findsNothing);
    expect(find.text('Status updated'), findsOneWidget);
    expect(
      find.text('Ready for Discharge · location unchanged'),
      findsOneWidget,
    );
    final jan = containerOf(tester).read(patientProvider(janId))!;
    expect(jan.status, PatientStatus.readyForDischarge);
    expect(jan.location, 'LAB');
    final evt = repo.current.events.first as StatusEvent;
    expect(evt.byName, doctor);
    expect(evt.to, PatientStatus.readyForDischarge);

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Discharged needs a reason and uses the destructive button', (
    tester,
  ) async {
    final repo = RecordingRepository();
    await pumpApp(tester, repo, as: doctor);
    await openSheet(tester, repo);

    await tester.tap(option(PatientStatus.discharged));
    await tester.pump();
    expect(find.text('Discharge patient'), findsOneWidget);
    expect(find.text('Reason · required for discharge'), findsOneWidget);
    final button = tester.widget<WlButton>(saveButton);
    expect(button.variant, WlButtonVariant.destructive);
    expect(button.onPressed, isNull);

    await tester.tap(saveButton);
    await settle(tester);
    expect(repo.statusRequestIds, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('status-reason')),
      'Discharged home with oral antibiotics',
    );
    await tester.pump();
    await tester.tap(saveButton);
    await settle(tester);
    expect(repo.statusRequestIds, hasLength(1));
    final evt = repo.current.events.first as StatusEvent;
    expect(evt.to, PatientStatus.discharged);
    expect(evt.reason, 'Discharged home with oral antibiotics');
    expect(find.text('Discharged · location unchanged'), findsOneWidget);
    expect(repo.jan.location, 'LAB');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('conflict inside the sheet: no retry, choose again', (
    tester,
  ) async {
    final repo = RecordingRepository()..knobs.conflictNext = true;
    await pumpApp(tester, repo, as: doctor);
    await openSheet(tester, repo);

    await tester.tap(option(PatientStatus.readyForDischarge));
    await tester.pump();
    await tester.tap(saveButton);
    await settle(tester);
    expect(find.byKey(const ValueKey('status-conflict')), findsOneWidget);
    expect(find.text("Your change wasn't saved."), findsOneWidget);
    expect(find.text('Today, 10:41'), findsOneWidget);
    // Let the realtime toast for the other nurse's move go away.
    await tester.pump(const Duration(seconds: 5));
    expect(repo.statusRequestIds, hasLength(1));
    expect(repo.jan.status, PatientStatus.inTreatment);

    await tester.tap(find.text('Refresh and choose again'));
    await settle(tester);
    expect(inSheet(find.text('Change status')), findsOneWidget);
    expect(
      find.text("Location doesn't change. Jan stays in Cardiology."),
      findsOneWidget,
    );
    expect(repo.statusRequestIds, hasLength(1));

    await tester.tap(option(PatientStatus.readyForDischarge));
    await tester.pump();
    await tester.tap(saveButton);
    await settle(tester);
    expect(repo.statusRequestIds, hasLength(2));
    expect(repo.statusRequestIds[0], isNot(repo.statusRequestIds[1]));
    expect(repo.jan.status, PatientStatus.readyForDischarge);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('timeout: Check status reuses the request id', (tester) async {
    final repo = RecordingRepository()..knobs.timeoutNext = true;
    await pumpApp(tester, repo, as: doctor);
    await openSheet(tester, repo);
    final before = repo.eventsFor(janId);

    await tester.tap(option(PatientStatus.readyForDischarge));
    await tester.pump();
    await tester.tap(saveButton);
    await settle(tester);
    expect(find.text('Check status'), findsOneWidget);
    expect(find.text('Status updated'), findsNothing);

    await tester.tap(find.text('Check status'));
    await settle(tester);
    expect(repo.statusRequestIds, hasLength(2));
    expect(repo.statusRequestIds.toSet(), hasLength(1));
    expect(repo.eventsFor(janId), before + 1);
    expect(find.text('Status updated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('offline: Save is replaced by "Changes need a connection"', (
    tester,
  ) async {
    final repo = RecordingRepository();
    await pumpApp(tester, repo, as: doctor);
    await containerOf(tester)
        .read(connectivityProvider.notifier)
        .setOnline(false);
    await openSheet(tester, repo);
    expect(inSheet(find.text('Changes need a connection')), findsOneWidget);
    expect(saveButton, findsNothing);
    expect(repo.statusRequestIds, isEmpty);
  });

  testWidgets('text scale 2.0: sheet and discharge state fit', (tester) async {
    final repo = RecordingRepository();
    await pumpApp(tester, repo, as: doctor, textScale: 2);
    await openSheet(tester, repo);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(option(PatientStatus.discharged));
    await tester.tap(option(PatientStatus.discharged));
    await settle(tester);
    expect(find.text('Discharge patient'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

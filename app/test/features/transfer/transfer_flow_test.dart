// Flows 1 (steps 4–7), 2 and offline (design/handoff/flows.md) for the
// nurse's transfer: destination sheet → confirm → server → success.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/status/presentation/change_status_sheet.dart';
import 'package:wardline/features/transfer/application/client_request.dart';
import 'package:wardline/features/transfer/presentation/choose_destination_sheet.dart';
import 'package:wardline/features/transfer/presentation/transfer_confirm_screen.dart';

import 'transfer_test_helpers.dart';

void main() {
  group('Flow 1: nurse transfers Jan from Laboratory to Radiology', () {
    testWidgets('search, current not selectable, confirm once, success, '
        'back to patient', (tester) async {
      final repo = RecordingRepository();
      await pumpApp(tester, repo);
      final profile = await openJanProfile(tester);
      final eventsBefore = repo.eventsFor(janId);

      unawaited(
        showChooseDestinationSheet(
          profile,
          patient: repo.jan,
          identifiedBy: 'NFC',
        ),
      );
      await settle(tester);

      // Step 4: sheet with suggestions, floors and the current department.
      expect(find.text('Move Jan Kowalczyk'), findsOneWidget);
      expect(find.text('From Laboratory · Ground floor'), findsOneWidget);
      expect(find.text('SUGGESTED'), findsOneWidget);
      expect(find.text('GROUND FLOOR'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);

      // The current department is not a button: tapping it does nothing.
      await tester.tap(find.byKey(const ValueKey('dest-LAB')));
      await settle(tester);
      expect(find.text('Move Jan Kowalczyk'), findsOneWidget);
      expect(find.byType(TransferConfirmScreen), findsNothing);

      // "rad" → Radiology is the only match.
      await tester.enterText(find.byType(TextField), 'rad');
      await settle(tester);
      expect(find.text('1 MATCH'), findsOneWidget);
      expect(find.byKey(const ValueKey('dest-RAD')), findsOneWidget);
      for (final other in ['ER', 'LAB', 'INT', 'CAR', 'ICU']) {
        expect(find.byKey(ValueKey('dest-$other')), findsNothing);
      }

      await tester.tap(find.byKey(const ValueKey('dest-RAD')));
      await settle(tester);

      // Step 5: confirm screen.
      expect(find.byType(TransferConfirmScreen), findsOneWidget);
      expect(find.text('Move Jan Kowalczyk'), findsNothing);
      expect(
        find.bySemanticsLabel('From Laboratory to Radiology'),
        findsOneWidget,
      );
      expect(find.text('Anna Nowak · Nurse'), findsOneWidget);
      expect(find.text('In Treatment · unchanged'), findsOneWidget);
      expect(repo.transferRequestIds, isEmpty);

      // Step 6: double tap → one RPC, spinner, back/cancel hidden.
      await tester.tap(confirmButton);
      await tester.tap(confirmButton, warnIfMissed: false);
      await tester.pump();
      expect(find.text('Confirming…'), findsOneWidget);
      expect(find.text('Waiting for the server'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.byTooltip('Back'), findsNothing);
      await tester.tap(confirmButton, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.textContaining('Patient moved'), findsNothing);

      await settle(tester);

      // Step 7: success only after the RPC returned.
      expect(repo.transferRequestIds, hasLength(1));
      expect(repo.eventsFor(janId), eventsBefore + 1);
      final evt = repo.current.events.first as LocationEvent;
      expect(evt.from, 'LAB');
      expect(evt.to, 'RAD');
      expect(evt.identifiedBy, 'NFC');
      expect(find.text('Patient moved to Radiology'), findsOneWidget);
      expect(
        find.text(
          'Confirmed by the server at 10:46. Every device sees it now.',
        ),
        findsOneWidget,
      );
      expect(find.text('Laboratory → Radiology'), findsOneWidget);

      await tester.tap(find.text('Back to patient'));
      await settle(tester);
      expect(locationOf(tester), '/patients/$janId');
      expect(find.byType(TransferConfirmScreen), findsNothing);
      final jan = containerOf(tester).read(patientProvider(janId))!;
      expect(jan.location, 'RAD');
      expect(jan.locationBy, 'Anna Nowak');
      expect(jan.status, PatientStatus.inTreatment);
    });

    testWidgets('cancel leaves without any write', (tester) async {
      final repo = RecordingRepository();
      await pumpApp(tester, repo);
      await openJanProfile(tester);
      await openConfirm(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.byType(TransferConfirmScreen), findsNothing);
      expect(repo.transferRequestIds, isEmpty);
      expect(repo.jan.location, 'LAB');
    });

    testWidgets('choosing a suggestion opens confirm for it', (tester) async {
      final repo = RecordingRepository();
      await pumpApp(tester, repo);
      final profile = await openJanProfile(tester);
      unawaited(showChooseDestinationSheet(profile, patient: repo.jan));
      await settle(tester);
      final chip = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('suggested-'),
      );
      expect(chip, findsWidgets);
      final code = (tester.widget(chip.first).key! as ValueKey<String>).value
          .replaceFirst('suggested-', '');
      expect(code, isNot('LAB'));
      await tester.tap(chip.first);
      await settle(tester);
      final screen = tester.widget<TransferConfirmScreen>(
        find.byType(TransferConfirmScreen),
      );
      expect(screen.patientId, janId);
      expect(screen.toCode, code);
    });
  });

  group('Flow 2: conflict (PT409)', () {
    Finder inConflict(String text) => find.descendant(
      of: find.byKey(const ValueKey('transfer-conflict')),
      matching: find.text(text),
    );

    testWidgets('canvas scenario: Marek Kowal moved Jan to Cardiology at '
        '10:41; who, when, where; no retry', (tester) async {
      final repo = RecordingRepository()..designConflictNext();
      await pumpApp(tester, repo);
      await openJanProfile(tester);
      await openConfirm(tester);

      await tester.tap(confirmButton);
      await settle(tester);

      expect(find.text('Patient was already moved'), findsOneWidget);
      expect(find.text("Your change wasn't saved."), findsOneWidget);
      expect(inConflict('Marek Kowal · Nurse'), findsOneWidget);
      expect(inConflict('Today, 10:41'), findsOneWidget);
      expect(inConflict('Laboratory → Cardiology'), findsOneWidget);
      expect(find.text('Patient moved to Radiology'), findsNothing);

      // No automatic retry: one call, no own event, even after waiting.
      final events = repo.eventsFor(janId);
      // Also lets the realtime toast for the other nurse's move go away.
      await tester.pump(const Duration(seconds: 5));
      expect(repo.transferRequestIds, hasLength(1));
      expect(repo.eventsFor(janId), events);
      expect(
        repo.current.events.whereType<LocationEvent>().where(
          (e) => e.patientId == janId && e.to == 'RAD' && e.from == 'LAB',
        ),
        isEmpty,
      );

      await tester.tap(find.text('Refresh and choose again'));
      await settle(tester);
      expect(locationOf(tester), '/patients/$janId');
      expect(containerOf(tester).read(patientProvider(janId))!.location, 'CAR');
      expect(repo.transferRequestIds, hasLength(1));
    });

    testWidgets('demo knob conflictNext: conflict sheet, event count '
        'unchanged after the conflict', (tester) async {
      final repo = RecordingRepository()..knobs.conflictNext = true;
      await pumpApp(tester, repo);
      await openConfirm(tester);
      await tester.tap(confirmButton);
      await settle(tester);

      final move = repo.current.events.first as LocationEvent;
      expect(find.text('Patient was already moved'), findsOneWidget);
      expect(inConflict('${move.byName} · Nurse'), findsOneWidget);
      expect(inConflict('Today, 10:41'), findsOneWidget);
      expect(inConflict('Laboratory → Cardiology'), findsOneWidget);

      final events = repo.eventsFor(janId);
      // Also lets the realtime toast for the other nurse's move go away.
      await tester.pump(const Duration(seconds: 5));
      expect(repo.transferRequestIds, hasLength(1));
      expect(repo.eventsFor(janId), events);

      await tester.tap(find.text('Back to patient'));
      await settle(tester);
      expect(locationOf(tester), '/patients/$janId');
    });
  });

  group('Timeout', () {
    testWidgets('Check status resends the same request id; one event lands', (
      tester,
    ) async {
      final repo = RecordingRepository()..knobs.timeoutNext = true;
      await pumpApp(tester, repo);
      await openConfirm(tester);
      final before = repo.eventsFor(janId);

      await tester.tap(confirmButton);
      await settle(tester);
      expect(find.text("We couldn't confirm the transfer"), findsOneWidget);
      expect(find.textContaining("Checking won't move Jan twice."), findsOne);
      final id = repo.transferRequestIds.single;
      expect(
        find.text('Request reference ${requestReference(id)}'),
        findsOneWidget,
      );
      expect(find.text('Patient moved to Radiology'), findsNothing);

      await tester.tap(find.text('Check status'));
      await settle(tester);
      expect(repo.transferRequestIds, [id, id]);
      expect(repo.eventsFor(janId), before + 1);
      expect(find.text('Patient moved to Radiology'), findsOneWidget);
    });
  });

  group('Offline', () {
    testWidgets('confirm is replaced by "Changes need a connection"', (
      tester,
    ) async {
      final repo = RecordingRepository();
      await pumpApp(tester, repo);
      await containerOf(tester)
          .read(connectivityProvider.notifier)
          .setOnline(false);
      await openConfirm(tester);
      expect(find.text('Changes need a connection'), findsOneWidget);
      expect(confirmButton, findsNothing);
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('Back to patient'), findsOneWidget);
      expect(repo.transferRequestIds, isEmpty);
    });

    testWidgets('connection drops while on the screen', (tester) async {
      final repo = RecordingRepository();
      await pumpApp(tester, repo);
      await openConfirm(tester);
      expect(confirmButton, findsOneWidget);
      await containerOf(tester)
          .read(connectivityProvider.notifier)
          .setOnline(false);
      await settle(tester);
      expect(confirmButton, findsNothing);
      expect(find.text('Changes need a connection'), findsOneWidget);
    });

    testWidgets('dropping mid-request ends on the offline note, no success', (
      tester,
    ) async {
      final repo = RecordingRepository();
      repo.knobs.latency = const Duration(milliseconds: 300);
      await pumpApp(tester, repo);
      await openConfirm(tester);
      await tester.tap(confirmButton);
      await tester.pump(const Duration(milliseconds: 50));
      repo.setOnline(false);
      await settle(tester, 20);
      expect(find.text('Patient moved to Radiology'), findsNothing);
      expect(find.text('Changes need a connection'), findsOneWidget);
      expect(repo.jan.location, 'LAB');
    });
  });

  group('Roles', () {
    testWidgets('doctor never gets the transfer sheet or confirm', (
      tester,
    ) async {
      final repo = RecordingRepository();
      await pumpApp(tester, repo, as: 'Dr Piotr Zając');
      final profile = await openJanProfile(tester);
      unawaited(showChooseDestinationSheet(profile, patient: repo.jan));
      await settle(tester);
      expect(find.text('Move Jan Kowalczyk'), findsNothing);

      await openConfirm(tester);
      expect(confirmButton, findsNothing);
      expect(find.text('Only nurses can move patients.'), findsOneWidget);
    });

    testWidgets('nurse never gets the status sheet', (tester) async {
      final repo = RecordingRepository();
      await pumpApp(tester, repo);
      final profile = await openJanProfile(tester);
      unawaited(showChangeStatusSheet(profile, patient: repo.jan));
      await settle(tester);
      expect(find.text('Change status'), findsNothing);
      expect(find.text('Save status'), findsNothing);
    });

    testWidgets('admin gets neither', (tester) async {
      final repo = RecordingRepository();
      await pumpApp(tester, repo, as: 'Katarzyna Wilk');
      final profile = await openJanProfile(tester);
      unawaited(showChooseDestinationSheet(profile, patient: repo.jan));
      unawaited(showChangeStatusSheet(profile, patient: repo.jan));
      await settle(tester);
      expect(find.byType(WlBottomSheet), findsNothing);
    });
  });

  group('Text scale 2.0', () {
    testWidgets('sheet, confirm, conflict and success do not overflow', (
      tester,
    ) async {
      final repo = RecordingRepository();
      await pumpApp(tester, repo, textScale: 2);
      final profile = await openJanProfile(tester);
      unawaited(showChooseDestinationSheet(profile, patient: repo.jan));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'rad');
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('dest-RAD')));
      await settle(tester);
      expect(tester.takeException(), isNull);

      repo.knobs.conflictNext = true;
      await tester.tap(confirmButton);
      await settle(tester);
      expect(find.text('Patient was already moved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('success and timeout at 2.0', (tester) async {
      final repo = RecordingRepository()..knobs.timeoutNext = true;
      await pumpApp(tester, repo, textScale: 2);
      await openConfirm(tester);
      await tester.tap(confirmButton);
      await settle(tester);
      expect(find.text('Check status'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Check status'));
      await settle(tester);
      expect(find.text('Patient moved to Radiology'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('reduced motion: static check, no moving dot', (tester) async {
    final repo = RecordingRepository();
    await pumpApp(tester, repo, reduceMotion: true);
    await openConfirm(tester);
    await tester.tap(confirmButton);
    await settle(tester);
    expect(find.text('Patient moved to Radiology'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

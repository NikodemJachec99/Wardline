// Goldens for the transfer journey (TransferFlow artboard steps 1, 2, 4, 5).
// Reduced motion keeps every frame static. Regenerate after an intended
// visual change:
//   flutter test --update-goldens test/features/transfer/transfer_goldens_test.dart
@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/features/transfer/presentation/choose_destination_sheet.dart';

import 'transfer_test_helpers.dart';

Future<void> _expectGolden(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  testWidgets('destination sheet', (tester) async {
    final repo = RecordingRepository();
    await pumpApp(tester, repo, reduceMotion: true);
    final profile = await openJanProfile(tester);
    unawaited(showChooseDestinationSheet(profile, patient: repo.jan));
    await settle(tester);
    await _expectGolden(tester, 'destination_sheet');
  });

  testWidgets('destination sheet, search "rad"', (tester) async {
    final repo = RecordingRepository();
    await pumpApp(tester, repo, reduceMotion: true);
    final profile = await openJanProfile(tester);
    unawaited(showChooseDestinationSheet(profile, patient: repo.jan));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'rad');
    await settle(tester);
    await _expectGolden(tester, 'destination_search');
  });

  testWidgets('confirm', (tester) async {
    final repo = RecordingRepository();
    await pumpApp(tester, repo, reduceMotion: true);
    await openJanProfile(tester);
    await openConfirm(tester);
    await _expectGolden(tester, 'confirm');
  });

  testWidgets('success', (tester) async {
    final repo = RecordingRepository();
    await pumpApp(tester, repo, reduceMotion: true);
    await openJanProfile(tester);
    await openConfirm(tester);
    await tester.tap(confirmButton);
    await settle(tester);
    await _expectGolden(tester, 'success');
  });

  testWidgets('conflict', (tester) async {
    final repo = RecordingRepository()..designConflictNext();
    await pumpApp(tester, repo, reduceMotion: true);
    await openJanProfile(tester);
    await openConfirm(tester);
    await tester.tap(confirmButton);
    await settle(tester);
    // The realtime toast about Marek's move hides after 4s.
    await tester.pump(const Duration(seconds: 5));
    await _expectGolden(tester, 'conflict');
  });

  testWidgets('offline', (tester) async {
    final repo = RecordingRepository();
    await pumpApp(tester, repo, reduceMotion: true);
    await openJanProfile(tester);
    await containerOf(tester)
        .read(connectivityProvider.notifier)
        .setOnline(false);
    await openConfirm(tester);
    await _expectGolden(tester, 'offline');
  });
}

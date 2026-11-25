// Goldens for the change-status sheet (StatusFlow artboard steps 1 and 4).
// Regenerate after an intended visual change:
//   flutter test --update-goldens test/features/status/status_goldens_test.dart
@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/features/status/presentation/change_status_sheet.dart';

import '../transfer/transfer_test_helpers.dart';

void main() {
  Future<void> open(WidgetTester tester, String choose) async {
    final repo = RecordingRepository();
    await pumpApp(tester, repo, as: 'Dr Piotr Zając', reduceMotion: true);
    final profile = await openJanProfile(tester);
    unawaited(showChangeStatusSheet(profile, patient: repo.jan));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('status-option-$choose')));
    await settle(tester);
  }

  testWidgets('status sheet: Ready for Discharge chosen', (tester) async {
    await open(tester, 'readyForDischarge');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/status_sheet.png'),
    );
  });

  testWidgets('status sheet: Discharged, reason required', (tester) async {
    await open(tester, 'discharged');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/status_sheet_discharge.png'),
    );
  });
}

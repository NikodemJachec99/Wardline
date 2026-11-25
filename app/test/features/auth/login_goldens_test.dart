// Goldens for the Login artboard. Regenerate after an intended change:
//   flutter test --update-goldens test/features/auth/login_goldens_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/app.dart';

import '../history/history_harness.dart';

void main() {
  testWidgets('sign in default', (tester) async {
    phone(tester);
    await pumpApp(tester, repo: clockedRepository(), as: null);
    await settle(tester);
    await expectLater(
      find.byType(WardlineApp),
      matchesGoldenFile('goldens/login.png'),
    );
  });

  testWidgets('sign in with wrong credentials', (tester) async {
    phone(tester);
    await pumpApp(tester, repo: clockedRepository(), as: null);
    await settle(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'anna.nowak@wardline.test');
    await tester.enterText(fields.last, 'nope');
    await tester.tap(find.text('Sign in'));
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    await expectLater(
      find.byType(WardlineApp),
      matchesGoldenFile('goldens/login_error.png'),
    );
  });
}

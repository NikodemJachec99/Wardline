import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/router.dart';

import '../../../helpers/harness.dart';
import '../../dashboard/dashboard_test_utils.dart';

Future<void> _open(WidgetTester tester, String route) async {
  await pumpDashboard(
    tester,
    repo: demoRepository(),
    as: 'Katarzyna Wilk',
    size: const Size(390, 1000),
  );
  unawaited(containerOf(tester).read(routerProvider).push(route));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Goldens next to the artboards DemoMode and Admin.
void main() {
  testWidgets('demo mode idle (DemoMode)', (tester) async {
    await _open(tester, Routes.demo);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('demo_mode.png'),
    );
  });

  testWidgets('demo mode running', (tester) async {
    useReducedMotion(tester); // static pulse dot for a stable frame
    await _open(tester, Routes.demo);
    await tester.tap(find.bySemanticsLabel('Run Live transfers'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Run Conflict'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('demo_mode_running.png'),
    );
    containerOf(tester).read(routerProvider).pop();
    // Toast (4 s) and the reduced-motion "Updated" dot (5 s) time out.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('admin staff (Admin)', (tester) async {
    await _open(tester, Routes.admin);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('admin_staff.png'),
    );
  });
}

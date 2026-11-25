import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/router.dart';

import '../../../helpers/harness.dart';
import '../../dashboard/dashboard_test_utils.dart';

/// Goldens next to the artboard Account (Notifications · Nurse / Doctor).
void main() {
  for (final (who, file) in [
    ('Anna Nowak', 'notifications_nurse.png'),
    ('Dr Piotr Zając', 'notifications_doctor.png'),
  ]) {
    testWidgets('notifications $who', (tester) async {
      await pumpDashboard(
        tester,
        repo: demoRepository(),
        as: who,
        size: const Size(390, 844),
      );
      unawaited(
        containerOf(tester).read(routerProvider).push(Routes.notifications),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile(file));
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/features/dashboard/presentation/dashboard_screen.dart';

import '../../../helpers/harness.dart';
import '../dashboard_test_utils.dart';

/// Goldens next to the artboards DashB, DashDoctor and DashLoading.
void main() {
  testWidgets('dashboard nurse (DashB)', (tester) async {
    await pumpDashboard(tester, repo: demoRepository());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('dashboard_nurse.png'),
    );
  });

  testWidgets('dashboard doctor (DashDoctor)', (tester) async {
    await pumpDashboard(tester, repo: demoRepository(), as: 'Dr Piotr Zając');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('dashboard_doctor.png'),
    );
  });

  testWidgets('dashboard loading (DashLoading)', (tester) async {
    useReducedMotion(tester); // static skeleton blocks, no shimmer frame
    await pumpDashboard(
      tester,
      repo: EmptyHospitalRepository(),
      size: const Size(390, 844),
    );
    expect(find.byType(DashboardScreen), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('dashboard_loading.png'),
    );
  });
}

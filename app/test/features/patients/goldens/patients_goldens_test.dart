// Golden tests for the Patients list and the patient profile (artboards
// `PatientsList`, `Profile`, `ProfileOffline`, `Platform`). Regenerate after
// an intended visual change:
//   flutter test --update-goldens test/features/patients/goldens/
@Tags(['golden'])
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/app.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/data/demo/demo_hospital_repository.dart';

import '../../../helpers/harness.dart';
import '../patients_test_utils.dart';

DemoHospitalRepository demoRepositoryOffline() =>
    demoRepository()..knobs.online = false;

/// Offline since 10:42 on the design clock (flow 4).
class _OfflineAt1042 extends ConnectivityController {
  @override
  ConnectivityStatus build() => ConnectivityStatus(
    state: WlConnectionState.offline,
    syncedAt: DateTime(2026, 11, 13, 10, 42),
  );
}

void _still(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  testWidgets('patients list', (tester) async {
    phone(tester);
    _still(tester);
    await openApp(tester);
    await expectLater(
      find.byType(WardlineApp),
      matchesGoldenFile('patients_list.png'),
    );
  });

  testWidgets('patients list offline', (tester) async {
    phone(tester);
    _still(tester);
    final repo = demoRepositoryOffline();
    await openApp(
      tester,
      repo: repo,
      overrides: [connectivityProvider.overrideWith(_OfflineAt1042.new)],
    );
    await expectLater(
      find.byType(WardlineApp),
      matchesGoldenFile('patients_list_offline.png'),
    );
  });

  testWidgets('profile nurse, full scroll', (tester) async {
    phone(tester, size: const Size(390, 1840));
    _still(tester);
    await openApp(tester, location: '/patients/$janId');
    await expectLater(
      find.byType(WardlineApp),
      matchesGoldenFile('profile_nurse.png'),
    );
  });

  testWidgets('profile offline', (tester) async {
    phone(tester);
    _still(tester);
    await openApp(
      tester,
      repo: demoRepositoryOffline(),
      location: '/patients/$janId',
      overrides: [connectivityProvider.overrideWith(_OfflineAt1042.new)],
    );
    await expectLater(
      find.byType(WardlineApp),
      matchesGoldenFile('profile_offline.png'),
    );
  });

  testWidgets('profile doctor at text scale 2.0', (tester) async {
    phone(tester);
    _still(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openApp(tester, as: 'Dr Piotr Zając', location: '/patients/$janId');
    await expectLater(
      find.byType(WardlineApp),
      matchesGoldenFile('profile_doctor_ax.png'),
    );
  });
}

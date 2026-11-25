import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/data/demo/demo_hospital_repository.dart';

import '../../helpers/harness.dart';

const String janId = 'p-HPT-7K3M9QX2';

/// Phone viewport from the artboards (390 × 844).
void phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pumps the app signed in as [as] and opens [location].
Future<DemoHospitalRepository> openApp(
  WidgetTester tester, {
  String as = 'Anna Nowak',
  String location = '/patients',
  DemoHospitalRepository? repo,
  List<Override> overrides = const [],
}) async {
  final r = repo ?? demoRepository();
  await tester.pumpWidget(appHarness(repo: r, as: as, overrides: overrides));
  await tester.pump();
  await go(tester, location);
  return r;
}

Future<void> go(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(WlBottomNav))).go(location);
  await settle(tester);
}

/// Pumps enough frames for page transitions without waiting on endless
/// animations (live pulse, skeleton shimmer).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(WlBottomNav)));

Future<void> goOffline(WidgetTester tester) async {
  await container(tester).read(connectivityProvider.notifier).setOnline(false);
  await settle(tester);
}

Finder cardOf(String name) => find.byWidgetPredicate(
  (w) => w is WlPatientCard && w.name == name,
  description: 'WlPatientCard($name)',
);

/// Lets toasts and highlights finish so no timers are left pending.
Future<void> drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 1));
}

// Shared setup for the History, Sign in and Profile screen tests: the demo
// hospital on the design clock (10:46), a phone-sized view and helpers to
// navigate the real router.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/app.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/data/demo/demo_hospital_repository.dart';
import 'package:wardline/data/demo/demo_seed.dart';
import 'package:wardline/features/history/presentation/history_data.dart';
import 'package:wardline/features/profile/presentation/profile_screen.dart';

import '../../helpers/harness.dart';

/// Demo hospital whose realtime events also happen at 10:46, so "today"
/// and "last 30 minutes" are stable.
DemoHospitalRepository clockedRepository({DateTime? now}) {
  final at = now ?? demoNow;
  final repo = DemoHospitalRepository(
    DemoSeed.fromJson(sampleJson(), now: demoNow),
    clock: () => at,
  );
  repo.knobs.latency = const Duration(milliseconds: 50);
  return repo;
}

/// Phone view (390 × 844) and optional text scale; reset after the test.
void phone(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Pumps the whole app on [location], signed in as [as].
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required DemoHospitalRepository repo,
  String? as = 'Anna Nowak',
  String? location,
  DateTime? now,
  bool push = false,
  List<Override> overrides = const [],
}) async {
  final clock = now ?? demoNow;
  await tester.pumpWidget(
    appHarness(
      repo: repo,
      as: as,
      overrides: [
        historyNowProvider.overrideWithValue(() => clock),
        profileNowProvider.overrideWithValue(() => clock),
        ...overrides,
      ],
    ),
  );
  await tester.pump();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(WardlineApp)),
  );
  if (location != null) {
    final router = container.read(routerProvider);
    if (push) {
      router.go(Routes.history);
      await tester.pump();
      unawaited(router.push<void>(location));
    } else {
      router.go(location);
    }
    await settle(tester);
  }
  return container;
}

/// Settles route transitions without waiting on endless animations.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets toasts (4s) and highlight timers (5s) finish before the test ends.
Future<void> drainTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 1));
}

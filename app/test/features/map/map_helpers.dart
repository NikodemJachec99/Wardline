import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/app.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/data/demo/demo_hospital_repository.dart';

import '../../helpers/harness.dart';

/// Phone viewport from the artboards (390 × 844).
const Size kPhone = Size(390, 844);

/// Tablet viewport from the Analytics / WardMonitor artboards.
const Size kTablet = Size(1194, 834);

void setViewport(WidgetTester tester, Size size, {double dpr = 2}) {
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

/// Pumps the app signed in as [as] and pushes [location].
Future<DemoHospitalRepository> openApp(
  WidgetTester tester,
  String location, {
  DemoHospitalRepository? repo,
  String as = 'Anna Nowak',
  bool reduceMotion = false,
  double textScale = 1,
}) async {
  final r = repo ?? demoRepository();
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await tester.pumpWidget(
    appHarness(
      repo: r,
      as: as,
      overrides: [
        if (reduceMotion)
          settingsProvider.overrideWith(_ReducedMotionSettings.new),
      ],
    ),
  );
  await tester.pump();
  unawaited(container(tester).read(routerProvider).push(location));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  return r;
}

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(WardlineApp)));

class _ReducedMotionSettings extends SettingsController {
  @override
  AppSettings build() => const AppSettings(reduceMotion: true);
}

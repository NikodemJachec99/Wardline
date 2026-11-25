// Golden screens for Analytics and the ward monitor (tablet 1194 × 834).
// Regenerate: flutter test --update-goldens test/features/analytics/goldens/
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/router.dart';

import '../../map/map_helpers.dart';

void main() {
  testWidgets('analytics, tablet', (tester) async {
    setViewport(tester, kTablet, dpr: 1);
    await openApp(tester, Routes.analytics, reduceMotion: true);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('analytics_tablet.png'),
    );
  });

  testWidgets('analytics, tablet, charts', (tester) async {
    setViewport(tester, kTablet, dpr: 1);
    await openApp(tester, Routes.analytics, reduceMotion: true);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('analytics_tablet_charts.png'),
    );
  });

  testWidgets('ward monitor INT, tablet', (tester) async {
    setViewport(tester, kTablet, dpr: 1);
    await openApp(tester, Routes.monitor('INT'), reduceMotion: true);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('ward_monitor_int.png'),
    );
  });
}

// Golden screens for the hospital map (MapLive / MapStates artboards).
// Regenerate: flutter test --update-goldens test/features/map/goldens/
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/router.dart';

import '../map_helpers.dart';

Future<void> _snap(WidgetTester tester, String name) async {
  await tester.pump(const Duration(seconds: 3));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('map_$name.png'),
  );
}

void main() {
  testWidgets('3D, all floors', (tester) async {
    setViewport(tester, kPhone);
    await openApp(tester, Routes.map, reduceMotion: true);
    await _snap(tester, '3d_all_floors');
  });

  testWidgets('2D, one floor', (tester) async {
    setViewport(tester, kPhone);
    await openApp(tester, Routes.mapFor(floor: 1), reduceMotion: true);
    await tester.tap(find.bySemanticsLabel('2D'));
    await _snap(tester, '2d_floor_1');
  });

  testWidgets('department sheet', (tester) async {
    setViewport(tester, kPhone);
    await openApp(
      tester,
      Routes.mapFor(floor: 1, department: 'INT'),
      reduceMotion: true,
    );
    await _snap(tester, 'department_sheet');
  });

  testWidgets('route today', (tester) async {
    setViewport(tester, kPhone);
    await openApp(
      tester,
      Routes.mapFor(patientId: 'p-HPT-7K3M9QX2'),
      reduceMotion: true,
    );
    await _snap(tester, 'route');
  });
}

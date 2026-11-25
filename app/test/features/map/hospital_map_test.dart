// Hospital map (screens.md › Hospital map, flows.md › flow 5,
// platform-and-a11y.md › Map).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/data/demo/demo_hospital_repository.dart';
import 'package:wardline/features/map/presentation/map_geometry.dart';
import 'package:wardline/features/map/presentation/map_painter.dart';

import '../../helpers/harness.dart';
import 'map_helpers.dart';

final _deptLabel = RegExp(r'^[A-Z][A-Za-z ]+, \d+ of \d+ beds, \d+ percent');

HospitalMapPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('hospital-map-paint')).last,
            )
            .painter!
        as HospitalMapPainter;

String _id(DemoHospitalRepository repo, String name) =>
    repo.current.patients.firstWhere((p) => p.fullName == name).id;

/// Two frames: one to start the route/sheet animation, one to finish it.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

String _location(WidgetTester tester) =>
    container(tester)
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .toString();

void main() {
  testWidgets('flow 5.1: 3D, three floors, 12 department buttons with '
      'occupancy semantics, bottlenecks on ICU and INT', (tester) async {
    final handle = tester.ensureSemantics();
    setViewport(tester, kPhone);
    await openApp(tester, Routes.map);

    expect(find.text('Hospital map'), findsOneWidget);
    expect(find.text('128/210 beds · 2 bottlenecks'), findsOneWidget);
    expect(find.bySemanticsLabel(_deptLabel), findsNWidgets(12));
    for (final label in [
      'Internal Medicine, 29 of 32 beds, 91 percent, bottleneck',
      'Intensive Care, 8 of 8 beds, 100 percent, bottleneck',
      'Radiology, 6 of 14 beds, 43 percent',
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, isButton: true),
      );
    }
    expect(find.bySemanticsLabel(RegExp('bottleneck\$')), findsNWidgets(2));
    final p = _painter(tester);
    expect(p.scene.projection.mode, MapMode.iso);
    expect(p.scene.projection.floors, [0, 1, 2]);
    expect(find.text('FLOOR 2'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('floor filter shows one floor; 2D/3D toggle', (tester) async {
    final handle = tester.ensureSemantics();
    setViewport(tester, kPhone);
    await openApp(tester, Routes.map, reduceMotion: true);

    await tester.tap(find.bySemanticsLabel('Ground'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.bySemanticsLabel(_deptLabel), findsNWidgets(4));
    expect(find.bySemanticsLabel(RegExp('^Internal Medicine,')), findsNothing);
    expect(_painter(tester).scene.projection.floors, [0]);

    await tester.tap(find.bySemanticsLabel('2D'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_painter(tester).scene.projection.mode, MapMode.flat);
    expect(find.bySemanticsLabel(_deptLabel), findsNWidgets(4));

    await tester.tap(find.bySemanticsLabel('3D'));
    await tester.tap(find.bySemanticsLabel('All'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_painter(tester).scene.projection.mode, MapMode.iso);
    expect(find.bySemanticsLabel(_deptLabel), findsNWidgets(12));
    handle.dispose();
  });

  testWidgets('flow 5.2: tap RAD → sheet with occupancy, free beds and the '
      'patients there; a patient opens the profile', (tester) async {
    final handle = tester.ensureSemantics();
    setViewport(tester, kPhone);
    final repo = await openApp(tester, Routes.map);

    await tester.tap(find.bySemanticsLabel(RegExp('^Radiology,')));
    await _settle(tester);

    expect(find.text('RAD · Ground'), findsOneWidget);
    expect(find.text('Radiology'), findsOneWidget);
    expect(find.text('6 of 14 beds · 43%'), findsOneWidget);
    expect(find.text('8 free'), findsOneWidget);
    expect(find.text('Adam Wójcik'), findsOneWidget);
    expect(find.text('Department history'), findsOneWidget);
    expect(_painter(tester).selected, 'RAD');

    await tester.tap(find.text('Adam Wójcik'));
    await _settle(tester);
    expect(_location(tester), Routes.patient(_id(repo, 'Adam Wójcik')));
    handle.dispose();
  });

  testWidgets('taps on a painted department polygon open its sheet', (
    tester,
  ) async {
    setViewport(tester, kPhone);
    await openApp(tester, Routes.mapFor(floor: 0), reduceMotion: true);

    final p = _painter(tester);
    final lab = p.scene.department('LAB')!;
    // Between the label and the right corner: outside the label button.
    final corner = lab.top.points[1];
    final local = lab.center + (corner - lab.center) * .75;
    final origin = tester.getTopLeft(
      find.byKey(const ValueKey('hospital-map-paint')),
    );
    expect(p.scene.hitTest(local), 'LAB');
    await tester.tapAt(origin + local);
    await _settle(tester);
    expect(find.text('LAB · Ground'), findsOneWidget);
    expect(find.text('Laboratory'), findsOneWidget);
    expect(find.text('Jan Kowalczyk'), findsOneWidget);
  });

  testWidgets('flow 5.3: find Jan → route with stops ER → RAD → INT → LAB, '
      'lift at each floor change, times', (tester) async {
    final handle = tester.ensureSemantics();
    setViewport(tester, kPhone);
    await openApp(tester, Routes.map);

    await tester.tap(find.text('Find patient'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'Kowalczyk');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Jan Kowalczyk'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Route today'), findsOneWidget);
    final expected = [
      'Stop 1, Emergency Department, 08:12',
      'Stop 2, Radiology, 08:47',
      'Stop 3, Internal Medicine, lift ↑ Floor 1, 09:35',
      'Stop 4, Laboratory, lift ↓ Ground, 10:31 · now',
    ];
    var lastY = -1.0;
    for (final (i, label) in expected.indexed) {
      final row = find.byKey(ValueKey('route-stop-$i'));
      expect(tester.getSemantics(row), isSemantics(label: label));
      final y = tester.getTopLeft(row).dy;
      expect(y, greaterThan(lastY));
      lastY = y;
    }
    // Numbered markers on the map, focusable in order.
    expect(
      find.bySemanticsLabel(RegExp(r'^Stop 4, Laboratory, 10:31, now$')),
      findsOneWidget,
    );
    // ER, RAD, lift 0, lift 1, INT, lift 1, lift 0, LAB.
    final p = _painter(tester);
    expect(p.route, hasLength(8));
    expect(p.routeProgress, 1);
    handle.dispose();
  });

  testWidgets('route param opens the route; department param the sheet', (
    tester,
  ) async {
    setViewport(tester, kPhone);
    final repo = demoRepository();
    await openApp(
      tester,
      Routes.mapFor(patientId: _id(repo, 'Jan Kowalczyk')),
      repo: repo,
      reduceMotion: true,
    );
    expect(find.text('Route today'), findsOneWidget);
    expect(find.text('Jan Kowalczyk'), findsOneWidget);
    // Reduced motion: the whole route at once.
    expect(_painter(tester).routeProgress, 1);
  });

  testWidgets('department param opens that sheet', (tester) async {
    setViewport(tester, kPhone);
    await openApp(tester, Routes.mapFor(department: 'ICU'));
    expect(find.text('ICU · Floor 2'), findsOneWidget);
    expect(find.text('Intensive Care'), findsOneWidget);
    expect(find.text('Full'), findsWidgets);
  });

  testWidgets('List view shows the same data as cards; tap opens sheet', (
    tester,
  ) async {
    setViewport(tester, kPhone);
    await openApp(tester, Routes.map);

    await tester.tap(find.text('List view'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('map-list-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('hospital-map-paint')), findsNothing);
    expect(find.text('Map view'), findsOneWidget);
    expect(find.byType(WlDepartmentCard), findsWidgets);
    expect(find.text('Emergency Department'), findsOneWidget);

    await tester.tap(find.text('Emergency Department'));
    await _settle(tester);
    expect(find.text('ER · Ground'), findsOneWidget);
    await tester.tap(find.widgetWithIcon(IconButton, WlIcons.close));
    await _settle(tester);

    await tester.tap(find.text('Map view'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('hospital-map-paint')), findsOneWidget);
  });

  testWidgets('remote transfer: dot travels A→B, then disappears', (
    tester,
  ) async {
    setViewport(tester, kPhone);
    final repo = await openApp(tester, Routes.map);
    repo.simulateRemoteTransfer(
      patientId: _id(repo, 'Maria Zielińska'),
      to: 'RAD',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    final p = _painter(tester);
    expect(p.movements, hasLength(1));
    expect(p.movements.single.t, inExclusiveRange(0, 1));
    expect(
      find.text('Maria Zielińska · Emergency → Radiology'),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 2000));
    expect(_painter(tester).movements, isEmpty);
    expect(_painter(tester).arrivals.keys, ['RAD']);
    await tester.pump(const Duration(seconds: 3));
    expect(_painter(tester).arrivals, isEmpty);
    expect(find.text('Maria Zielińska · Emergency → Radiology'), findsNothing);
  });

  testWidgets('remote transfer with reduced motion: highlight on B, no dot', (
    tester,
  ) async {
    setViewport(tester, kPhone);
    final repo = await openApp(tester, Routes.map, reduceMotion: true);
    repo.simulateRemoteTransfer(
      patientId: _id(repo, 'Maria Zielińska'),
      to: 'RAD',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final p = _painter(tester);
    expect(p.movements, isEmpty);
    expect(p.arrivals, {'RAD': 0});
    expect(
      find.text('Maria Zielińska · Emergency → Radiology'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Radiology, 7 of 14 beds, 50 percent'),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 2100));
    expect(_painter(tester).arrivals, isEmpty);
  });

  testWidgets('offline: banner, map still readable', (tester) async {
    setViewport(tester, kPhone);
    await openApp(tester, Routes.map);
    await container(tester)
        .read(connectivityProvider.notifier)
        .setOnline(false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.byKey(const ValueKey('hospital-map-paint')), findsOneWidget);
  });

  testWidgets('text scale 2.0: map and list view do not overflow', (
    tester,
  ) async {
    setViewport(tester, kPhone);
    await openApp(tester, Routes.map, textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('List view'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Rehabilitation'),
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('map-list-view')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.text('Rehabilitation'), findsOneWidget);
    await tester.tap(find.text('Rehabilitation'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('REH · Floor 2'), findsOneWidget);
  });
}

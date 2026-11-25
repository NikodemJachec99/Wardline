// WlMiniMap and WlDepartmentCard (components.md › WlMiniMap ·
// WlDepartmentCard; Dashboard and MapStates artboards).
// Regenerate goldens:
//   flutter test --update-goldens test/core/widgets/wl_map_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/app/theme.dart';
import 'package:wardline/core/theme/wl_tokens.dart';
import 'package:wardline/core/widgets/wl/wl.dart';

import '../../helpers/harness.dart';

Widget _host(Widget child, {bool scope = true, double textScale = 1}) {
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  if (!scope) return app;
  return ProviderScope(
    overrides: [hospitalRepositoryProvider.overrideWithValue(demoRepository())],
    child: app,
  );
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

const _icu = WlDepartmentCard(
  code: 'ICU',
  name: 'Intensive Care',
  floor: 2,
  occupied: 8,
  beds: 8,
  breakdown: {PatientStatus.admitted: 1, PatientStatus.inTreatment: 7},
);

const _lab = WlDepartmentCard(
  code: 'LAB',
  name: 'Laboratory',
  floor: 0,
  occupied: 5,
  beds: 12,
  breakdown: {PatientStatus.admitted: 1, PatientStatus.inTreatment: 4},
);

void main() {
  group('WlMiniMap', () {
    testWidgets('golden: Ground floor, LAB highlighted, JK pin', (
      tester,
    ) async {
      _viewport(tester, const Size(390, 460));
      await tester.pumpWidget(
        _host(
          Column(
            spacing: 16,
            children: [
              WlMiniMap(
                floor: 0,
                highlightDepartment: 'LAB',
                patientInitials: 'JK',
                onTap: () {},
              ),
              const WlMiniMap(floor: 1, highlightDepartment: 'INT'),
            ],
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/wl_mini_map.png'),
      );
    });

    testWidgets('tap opens the map; label names floor and department', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _host(
          WlMiniMap(
            floor: 0,
            highlightDepartment: 'LAB',
            patientInitials: 'JK',
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel(
          'Map of Ground floor, Laboratory highlighted, patient is here. '
          'Open map',
        ),
        findsOneWidget,
      );
      expect(find.text('JK'), findsOneWidget);
      expect(find.text('Ground floor'), findsOneWidget);
      await tester.tap(find.byType(WlMiniMap));
      expect(taps, 1);
      expect(tester.getSize(find.byType(WlMiniMap)).height, greaterThan(48));
      handle.dispose();
    });

    testWidgets('outside a ProviderScope it still renders', (tester) async {
      await tester.pumpWidget(_host(const WlMiniMap(floor: 2), scope: false));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Floor 2'), findsOneWidget);
    });
  });

  group('WlDepartmentCard', () {
    testWidgets('golden: full ICU and LAB', (tester) async {
      _viewport(tester, const Size(390, 520));
      await tester.pumpWidget(
        _host(const Column(spacing: 16, children: [_icu, _lab])),
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/wl_department_card.png'),
      );
    });

    testWidgets('shows code · floor, name, %, free beds and breakdown', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const Column(children: [_icu, _lab])));
      expect(find.text('ICU'), findsOneWidget);
      expect(find.text('Floor 2'), findsOneWidget);
      expect(find.text('Intensive Care'), findsOneWidget);
      expect(find.text('100% · Full'), findsOneWidget);
      expect(find.text('0 free of 8'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      expect(find.text('7 free of 12'), findsOneWidget);
      expect(find.text('Ground'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Intensive Care, Floor 2, 8 of 8 beds, 100 percent, full, 0 free, '
          'Admitted 1, In Treatment 7',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('flag word and tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          WlDepartmentCard(
            code: 'INT',
            name: 'Internal Medicine',
            floor: 1,
            occupied: 29,
            beds: 32,
            flag: 'Bottleneck',
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('91% · Bottleneck'), findsOneWidget);
      await tester.tap(find.byType(WlDepartmentCard));
      expect(taps, 1);
    });

    testWidgets('text scale 2.0 does not overflow', (tester) async {
      _viewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        _host(const Column(children: [_icu, _lab]), textScale: 2),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

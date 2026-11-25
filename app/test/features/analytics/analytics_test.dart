// Analytics and ward monitor (screens.md, platform-and-a11y.md › Charts).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/analytics/presentation/analytics_widgets.dart';

import '../map/map_helpers.dart';

Finder _inCard(String title, Finder matching) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(ChartCard)),
  matching: matching,
);

Future<void> _scrollTo(WidgetTester tester, Finder f) => tester
    .scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);

void main() {
  group('Analytics', () {
    testWidgets('tablet: KPI tiles, occupancy grid, bottlenecks', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      setViewport(tester, kTablet, dpr: 1);
      await openApp(tester, Routes.analytics);

      expect(find.text('Analytics'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Patients in house, 128,')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Bed occupancy, 61%, 128 of 210 beds'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Transfers today, 42, peak 09:00–10:00 · 11'),
        findsOneWidget,
      );
      expect(find.text('Occupancy & live movement'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Internal Medicine, 29 of 32 beds, 91 percent, bottleneck'),
        ),
        findsWidgets,
      );
      expect(find.text('Bottlenecks'), findsOneWidget);
      // Read-only: no write actions anywhere.
      expect(find.text('Transfer patient'), findsNothing);
      expect(find.text('Change status'), findsNothing);
      handle.dispose();
    });

    testWidgets('transfers-per-hour chart: one-sentence summary and '
        '"Show as table"', (tester) async {
      final handle = tester.ensureSemantics();
      setViewport(tester, kTablet, dpr: 1);
      await openApp(tester, Routes.analytics, reduceMotion: true);

      await _scrollTo(tester, find.text('Peak hours'));
      expect(
        find.bySemanticsLabel('Peak 09:00–10:00 with 11 transfers'),
        findsOneWidget,
      );
      final toggle = _inCard('Peak hours', find.text('Show as table'));
      await tester.ensureVisible(toggle);
      await tester.pump();
      await tester.tap(toggle);
      await tester.pump();
      expect(_inCard('Peak hours', find.text('Show as chart')), findsOneWidget);
      expect(_inCard('Peak hours', find.text('HOUR')), findsOneWidget);
      expect(_inCard('Peak hours', find.text('09:00–10:00')), findsOneWidget);
      expect(_inCard('Peak hours', find.text('11')), findsOneWidget);
      expect(_inCard('Peak hours', find.text('10:00–11:00')), findsOneWidget);
      expect(_inCard('Peak hours', find.text('9 (so far)')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Peak 09:00–10:00 with 11 transfers'),
        findsNothing,
      );

      final back = _inCard('Peak hours', find.text('Show as chart'));
      await tester.ensureVisible(back);
      await tester.pump();
      await tester.tap(back);
      await tester.pump();
      expect(
        find.bySemanticsLabel('Peak 09:00–10:00 with 11 transfers'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('flow chart and "now vs 07:00" have summaries and tables', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      setViewport(tester, kTablet, dpr: 1);
      await openApp(tester, Routes.analytics, reduceMotion: true);
      await _scrollTo(tester, find.text('Patient flow today'));
      expect(
        find.bySemanticsLabel(RegExp(r'^42 transfers today\. Most patients')),
        findsOneWidget,
      );
      await _scrollTo(tester, find.text('Now vs 07:00'));
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Since 07:00, [+−]\d+ patients overall'),
        ),
        findsOneWidget,
      );
      final toggle = _inCard('Now vs 07:00', find.text('Show as table'));
      await tester.ensureVisible(toggle);
      await tester.pump();
      await tester.tap(toggle);
      await tester.pump();
      expect(_inCard('Now vs 07:00', find.text('DEPARTMENT')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('phone stacks the same blocks; text scale 2.0', (tester) async {
      setViewport(tester, kPhone);
      await openApp(tester, Routes.analytics, textScale: 2);
      expect(tester.takeException(), isNull);
      for (final title in [
        'Occupancy & live movement',
        'Bottlenecks',
        'Patient flow today',
        'NFC vs QR',
        'Peak hours',
        'Now vs 07:00',
      ]) {
        await _scrollTo(tester, find.text(title));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('tablet at text scale 2.0', (tester) async {
      setViewport(tester, kTablet, dpr: 1);
      await openApp(tester, Routes.analytics, textScale: 2);
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, find.text('Now vs 07:00'));
      expect(tester.takeException(), isNull);
    });
  });

  group('Ward monitor', () {
    testWidgets('renders INT: occupancy, table, feed', (tester) async {
      final handle = tester.ensureSemantics();
      setViewport(tester, kTablet, dpr: 1);
      await openApp(tester, Routes.monitor('INT'));

      expect(find.text('Internal Medicine'), findsOneWidget);
      expect(find.text('INT · Floor 1 · Ward monitor'), findsOneWidget);
      expect(find.text('91% · 3 free'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Internal Medicine, 29 of 32 beds, 91 percent, bottleneck',
        ),
        findsOneWidget,
      );
      expect(find.text('PATIENT'), findsOneWidget);
      expect(find.text('Krystyna Mazur'), findsNothing); // inside rich text
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Krystyna Mazur, 72, Ready for Discharge'),
        ),
        findsOneWidget,
      );
      expect(find.text('Recent movements'), findsOneWidget);
      expect(find.text('Jan Kowalczyk → Laboratory'), findsOneWidget);
      expect(find.text('Showing 29 of 29 · Ready first'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('filters narrow the table', (tester) async {
      setViewport(tester, kTablet, dpr: 1);
      await openApp(tester, Routes.monitor('INT'));
      await tester.tap(find.text('Ready for Discharge'));
      await tester.pump();
      expect(
        find.textContaining(RegExp(r'^Showing \d+ of 29')),
        findsOneWidget,
      );
      final shown = tester
          .widget<Text>(find.textContaining(RegExp(r'^Showing \d+ of 29')))
          .data!;
      expect(shown, isNot('Showing 29 of 29 · Ready first'));
      final chips = tester.widgetList<WlStatusChip>(find.byType(WlStatusChip));
      expect(chips, isNotEmpty);
      expect(chips.map((c) => c.status).toSet(), {
        PatientStatus.readyForDischarge,
      });
    });

    testWidgets('unknown department', (tester) async {
      setViewport(tester, kTablet, dpr: 1);
      await openApp(tester, Routes.monitor('XYZ'));
      expect(find.text('Department not found'), findsOneWidget);
    });

    testWidgets('phone and text scale 2.0', (tester) async {
      setViewport(tester, kPhone);
      await openApp(tester, Routes.monitor('INT'), textScale: 2);
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, find.text('Recent movements'));
      expect(tester.takeException(), isNull);
    });
  });
}

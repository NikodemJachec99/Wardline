import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/core/format.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/features/history/presentation/day_timeline_screen.dart';
import 'package:wardline/features/history/presentation/history_data.dart';

import '../../helpers/harness.dart';
import 'history_harness.dart';

Finder get _plot => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is DayTimelinePainter,
);

void main() {
  testWidgets('paints the day with a summary for screen readers', (
    tester,
  ) async {
    phone(tester);
    final handle = tester.ensureSemantics();
    final repo = clockedRepository();
    await pumpApp(tester, repo: repo, location: Routes.dayTimeline, push: true);

    expect(_plot, findsOneWidget);
    final transfers = transfersOn(repo.current, demoNow);
    expect(find.text('${transfers.length} transfers · 00:00–24:00'), findsOne);
    expect(
      find.bySemanticsLabel(
        RegExp('Day timeline. Peak 09:00–10:00 with 11 transfers'),
      ),
      findsOneWidget,
    );
    final painter =
        tester.widget<CustomPaint>(_plot).painter! as DayTimelinePainter;
    expect(painter.marks, hasLength(transfers.length));
    expect(painter.now, demoNow);
    handle.dispose();
  });

  testWidgets('tapping a dot shows its details; list view is the same data', (
    tester,
  ) async {
    phone(tester);
    final repo = clockedRepository();
    await pumpApp(tester, repo: repo, location: Routes.dayTimeline, push: true);
    final s = repo.current;
    final last = transfersOn(s, demoNow).last;
    final row = s.departments.indexWhere((d) => d.code == last.to);
    final origin = tester.getTopLeft(_plot);
    final x = 14 + (last.at.hour + last.at.minute / 60) * 40;
    final y = 30 + row * 36 + 18;
    await tester.tapAt(origin + Offset(x, y.toDouble()));
    await tester.pump();

    final name = s.patient(last.patientId)!.fullName;
    expect(find.text('${hm(last.at)} · $name'), findsOneWidget);
    final painter =
        tester.widget<CustomPaint>(_plot).painter! as DayTimelinePainter;
    expect(painter.selected, isNotNull);

    await tester.tap(find.text('Show as list'));
    await settle(tester);
    expect(find.byType(WlActivityFeedItem), findsWidgets);
    expect(find.text('Hide list'), findsOneWidget);
  });

  testWidgets('a day without transfers shows the empty state', (tester) async {
    phone(tester);
    await pumpApp(
      tester,
      repo: clockedRepository(),
      location: Routes.dayTimeline,
      push: true,
      now: demoNow.add(const Duration(days: 2)),
    );
    expect(find.text('No transfers today'), findsOneWidget);
    expect(_plot, findsNothing);
  });

  testWidgets('text scale 2.0 renders without overflow', (tester) async {
    phone(tester, textScale: 2);
    await pumpApp(
      tester,
      repo: clockedRepository(),
      location: Routes.dayTimeline,
      push: true,
    );
    expect(tester.takeException(), isNull);
    expect(_plot, findsOneWidget);
  });

  test('summary names the busiest hour', () {
    expect(timelineSummary(const []), 'No transfers today');
  });
}

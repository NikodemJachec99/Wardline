// Goldens for the HistoryFlow artboard screens. Regenerate after an intended
// visual change:
//   flutter test --update-goldens test/features/history/history_goldens_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/app.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/features/history/presentation/day_timeline_screen.dart';
import 'package:wardline/features/history/presentation/history_data.dart';

import '../../helpers/harness.dart';

import 'history_harness.dart';

Future<void> _shot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(WardlineApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  testWidgets('history', (tester) async {
    phone(tester);
    await pumpApp(tester, repo: clockedRepository(), location: Routes.history);
    await _shot(tester, 'history');
  });

  testWidgets('department history INT', (tester) async {
    phone(tester);
    await pumpApp(
      tester,
      repo: clockedRepository(),
      location: Routes.departmentHistory('INT'),
      push: true,
    );
    await _shot(tester, 'department_history');
  });

  testWidgets('day timeline with a selected dot', (tester) async {
    phone(tester);
    final repo = clockedRepository();
    await pumpApp(tester, repo: repo, location: Routes.dayTimeline, push: true);
    final s = repo.current;
    final pick = transfersOn(s, demoNow).lastWhere((e) => e.to == 'LAB');
    final row = s.departments.indexWhere((d) => d.code == pick.to);
    final plot = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is DayTimelinePainter,
    );
    final x = 14 + (pick.at.hour + pick.at.minute / 60) * 40;
    await tester.tapAt(
      tester.getTopLeft(plot) + Offset(x, 30 + row * 36 + 18.0),
    );
    await tester.pump();
    await _shot(tester, 'day_timeline');
  });
}

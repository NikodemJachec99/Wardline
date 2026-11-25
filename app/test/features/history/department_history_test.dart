import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/history/presentation/history_data.dart';

import '../../helpers/harness.dart';
import 'history_harness.dart';

void main() {
  testWidgets('INT tiles count arrivals, departures and status today', (
    tester,
  ) async {
    phone(tester);
    final repo = clockedRepository();
    await pumpApp(
      tester,
      repo: repo,
      location: Routes.departmentHistory('INT'),
      push: true,
    );
    final s = repo.current;

    // Counted independently of the screen helpers.
    final today = s.events.where(
      (e) =>
          e.at.year == demoNow.year &&
          e.at.month == demoNow.month &&
          e.at.day == demoNow.day,
    );
    final arrivals = today
        .whereType<LocationEvent>()
        .where((e) => e.to == 'INT')
        .length;
    final departures = today
        .whereType<LocationEvent>()
        .where((e) => e.from == 'INT')
        .length;
    expect(arrivals, greaterThan(0));
    expect(departures, greaterThan(0));

    final handle = tester.ensureSemantics();
    expect(find.text('Internal Medicine'), findsOneWidget);
    expect(find.text('INT · Floor 1'), findsOneWidget);
    expect(find.bySemanticsLabel('$arrivals in today'), findsOneWidget);
    expect(find.bySemanticsLabel('$departures out today'), findsOneWidget);
    final pct = (s.occupancy('INT') * 100 / 32).round();
    expect(
      find.bySemanticsLabel(RegExp('^Occupancy $pct percent, ')),
      findsOneWidget,
    );
    expect(find.text('$pct%'), findsOneWidget);
    expect(find.text('${s.occupancy('INT')}/32 beds'), findsOneWidget);
    handle.dispose();

    final day = departmentDay(s, 'INT', demoNow);
    expect(day.arrivals, arrivals);
    expect(day.departures, departures);
  });

  testWidgets('In / Out / Status segments filter the feed', (tester) async {
    phone(tester);
    await pumpApp(
      tester,
      repo: clockedRepository(),
      location: Routes.departmentHistory('INT'),
      push: true,
    );
    expect(find.text('TODAY'), findsOneWidget);

    await tester.tap(find.text('In'));
    await settle(tester);
    expect(find.text('IN'), findsWidgets);
    expect(find.text('OUT'), findsNothing);

    await tester.tap(find.text('Out'));
    await settle(tester);
    expect(find.text('OUT'), findsWidgets);
    expect(find.text('IN'), findsNothing);

    await tester.tap(find.text('Status'));
    await settle(tester);
    expect(find.text('OUT'), findsNothing);
    expect(find.text('IN'), findsNothing);
  });

  testWidgets('empty filter names the direction and offers all activity', (
    tester,
  ) async {
    phone(tester);
    final repo = clockedRepository();
    final s = repo.current;
    const labels = {
      DeptSegment.departures: ('Out', 'No transfers out of'),
      DeptSegment.arrivals: ('In', 'No transfers into'),
      DeptSegment.status: ('Status', 'No status changes in'),
    };
    late final Department quiet;
    late final DeptSegment segment;
    var found = false;
    for (final seg in labels.keys) {
      for (final d in s.departments) {
        if (!found &&
            departmentEvents(s, d.code, demoNow, segment: seg).isEmpty) {
          quiet = d;
          segment = seg;
          found = true;
        }
      }
    }
    expect(found, isTrue);
    await pumpApp(
      tester,
      repo: repo,
      location: Routes.departmentHistory(quiet.code),
      push: true,
    );

    final (tab, prefix) = labels[segment]!;
    await tester.tap(find.text(tab));
    await settle(tester);
    expect(find.text('$prefix ${quiet.shortName} today'), findsOneWidget);
    expect(
      find.textContaining('${s.occupancy(quiet.code)} patient'),
      findsOneWidget,
    );
    await tester.tap(find.text('Show all activity'));
    await settle(tester);
    expect(find.text('Show all activity'), findsNothing);
  });

  testWidgets('unknown department says so', (tester) async {
    phone(tester);
    await pumpApp(
      tester,
      repo: clockedRepository(),
      location: Routes.departmentHistory('XYZ'),
      push: true,
    );
    expect(find.text('Department not found'), findsOneWidget);
  });

  testWidgets('text scale 2.0 stacks the tiles without overflow', (
    tester,
  ) async {
    phone(tester, textScale: 2);
    await pumpApp(
      tester,
      repo: clockedRepository(),
      location: Routes.departmentHistory('INT'),
      push: true,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Internal Medicine'), findsOneWidget);
  });
}

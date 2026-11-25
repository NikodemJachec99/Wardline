import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/core/format.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/history/presentation/day_timeline_screen.dart';
import 'package:wardline/features/history/presentation/department_history_screen.dart';
import 'package:wardline/features/history/presentation/history_data.dart';
import 'package:wardline/features/history/presentation/history_screen.dart';
import 'package:wardline/features/patients/presentation/patient_profile_screen.dart';

import '../../helpers/harness.dart';
import 'history_harness.dart';

List<WlActivityFeedItem> feedItems(WidgetTester tester) => tester
    .widgetList<WlActivityFeedItem>(find.byType(WlActivityFeedItem))
    .toList();

void main() {
  testWidgets('shows today with sections, newest first, absolute times', (
    tester,
  ) async {
    phone(tester);
    final repo = clockedRepository();
    await pumpApp(tester, repo: repo, location: Routes.history);

    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('LAST 30 MINUTES'), findsOneWidget);
    final items = feedItems(tester);
    expect(items, isNotEmpty);
    // Newest first, absolute times.
    final s = repo.current;
    final newest = s.events.first;
    expect(items.first.patientName, s.patient(newest.patientId)!.fullName);
    expect(items.first.timeAgo, hm(newest.at));
    // Jan's move to the lab at 10:31 reads like the artboard row.
    final jan = items.firstWhere((i) => i.patientName == 'Jan Kowalczyk');
    expect(jan.timeAgo, '10:31');
    expect(jan.subline, 'Internal Medicine → Laboratory · Nurse');
  });

  testWidgets('segments filter transfers and status changes', (tester) async {
    phone(tester);
    await pumpApp(tester, repo: clockedRepository(), location: Routes.history);

    await tester.tap(find.text('Transfers'));
    await settle(tester);
    var items = feedItems(tester);
    expect(items, isNotEmpty);
    expect(items.every((i) => i.action == 'moved'), isTrue);

    await tester.tap(find.text('Status'));
    await settle(tester);
    items = feedItems(tester);
    expect(items, isNotEmpty);
    expect(items.every((i) => i.action == 'updated'), isTrue);

    await tester.tap(find.text('All'));
    await settle(tester);
    final actions = feedItems(tester).map((i) => i.action).toSet();
    expect(actions.containsAll({'moved', 'updated'}), isTrue);
  });

  testWidgets('a remote transfer appears on top with the live highlight', (
    tester,
  ) async {
    phone(tester);
    final repo = clockedRepository();
    await pumpApp(tester, repo: repo, location: Routes.history);
    final patient = repo.current.patients.firstWhere(
      (p) => p.lastName == 'Mazur',
    );

    repo.simulateRemoteTransfer(patientId: patient.id, to: 'RAD');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final top = feedItems(tester).first;
    expect(top.patientName, patient.fullName);
    expect(top.live, isTrue);
    expect(top.highlightKey, repo.current.lastRemoteEvent!.id);
    expect(feedItems(tester).where((i) => i.live), hasLength(1));
    await drainTimers(tester);
  });

  testWidgets('department filter narrows the feed and links to its history', (
    tester,
  ) async {
    phone(tester);
    final repo = clockedRepository();
    await pumpApp(tester, repo: repo, location: Routes.history);

    await tester.tap(find.text('All departments'));
    await settle(tester);
    await tester.tap(find.text('Cardiology').last);
    await settle(tester);

    final s = repo.current;
    final expected = filterHistory(
      s,
      kind: HistoryKind.all,
      range: HistoryRange.today,
      now: demoNow,
      department: 'CAR',
    );
    expect(expected, isNotEmpty);
    final names = {for (final e in expected) s.patient(e.patientId)!.fullName};
    for (final item in feedItems(tester)) {
      expect(names, contains(item.patientName));
    }

    await tester.tap(find.text('Cardiology history'));
    await settle(tester);
    expect(find.byType(DepartmentHistoryScreen), findsOneWidget);
    expect(
      tester
          .widget<DepartmentHistoryScreen>(find.byType(DepartmentHistoryScreen))
          .departmentCode,
      'CAR',
    );
  });

  testWidgets('empty filter explains and offers all activity', (tester) async {
    phone(tester);
    final repo = clockedRepository();
    await pumpApp(tester, repo: repo, location: Routes.history);
    final s = repo.current;
    final quiet = s.departments.firstWhere(
      (d) => filterHistory(
        s,
        kind: HistoryKind.status,
        range: HistoryRange.lastHour,
        now: demoNow,
        department: d.code,
      ).isEmpty,
    );

    await tester.tap(find.text('All departments'));
    await settle(tester);
    await tester.tap(find.text(quiet.name).last);
    await settle(tester);
    await tester.tap(find.text('Today'));
    await settle(tester);
    await tester.tap(find.text('Last hour').last);
    await settle(tester);
    await tester.tap(find.text('Status'));
    await settle(tester);

    expect(
      find.text('No status changes in ${quiet.shortName} in the last hour'),
      findsOneWidget,
    );
    expect(feedItems(tester), isEmpty);
    await tester.tap(find.text('Show all activity'));
    await settle(tester);
    expect(feedItems(tester), isNotEmpty);
    expect(find.text('All departments'), findsOneWidget);
  });

  testWidgets('tapping a row opens the patient; header opens the timeline', (
    tester,
  ) async {
    phone(tester);
    final repo = clockedRepository();
    await pumpApp(tester, repo: repo, location: Routes.history);

    await tester.tap(find.byTooltip('Day timeline'));
    await settle(tester);
    expect(find.byType(DayTimelineScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    await tester.tap(find.byType(WlActivityFeedItem).first);
    await settle(tester);
    final profile = tester.widget<PatientProfileScreen>(
      find.byType(PatientProfileScreen),
    );
    expect(profile.patientId, repo.current.events.first.patientId);
  });

  testWidgets('offline shows the banner and the cached feed', (tester) async {
    phone(tester);
    final container = await pumpApp(
      tester,
      repo: clockedRepository(),
      location: Routes.history,
    );
    await container.read(connectivityProvider.notifier).setOnline(false);
    await settle(tester);
    expect(find.byType(WlOfflineBanner), findsOneWidget);
    expect(feedItems(tester), isNotEmpty);
  });

  testWidgets('all rows have 48dp targets and a label', (tester) async {
    phone(tester);
    final handle = tester.ensureSemantics();
    await pumpApp(tester, repo: clockedRepository(), location: Routes.history);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('text scale 2.0 renders without overflow', (tester) async {
    phone(tester, textScale: 2);
    await pumpApp(tester, repo: clockedRepository(), location: Routes.history);
    expect(tester.takeException(), isNull);
    expect(find.byType(WlActivityFeedItem), findsWidgets);
  });

  test('status rows belong to the department the patient was in', () {
    final repo = clockedRepository();
    final s = repo.current;
    final status = s.events.whereType<StatusEvent>().first;
    final where = locationAt(s, status.patientId, status.at);
    expect(where, isNotNull);
    expect(touchesDepartment(s, status, where!), isTrue);
  });
}

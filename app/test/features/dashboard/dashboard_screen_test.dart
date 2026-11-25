import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/dashboard/application/clock.dart';
import 'package:wardline/features/dashboard/application/dashboard_stats.dart';
import 'package:wardline/features/dashboard/presentation/dashboard_screen.dart';
import 'package:wardline/features/notifications/presentation/notifications_screen.dart';

import '../../helpers/harness.dart';
import 'dashboard_test_utils.dart';

void main() {
  testWidgets('nurse: greeting, KPIs from the snapshot after count-up', (
    tester,
  ) async {
    await pumpDashboard(tester, repo: demoRepository());

    expect(find.text('Good morning, Anna'), findsOneWidget);
    expect(find.text('Nurse · Day shift 07:00–19:00'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    expect(find.text('54'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    for (final l in [
      'Total patients',
      'In treatment',
      'Ready for discharge',
      'Transfers today',
    ]) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('Recent transfers'), findsOneWidget);
    expect(find.text('Recent status changes'), findsNothing);
    expect(find.text('Hospital map'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KPI count-up starts below the final value', (tester) async {
    await tester.pumpWidget(
      dashboardApp(repo: demoRepository(), as: 'Anna Nowak'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('128'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('128'), findsOneWidget);
  });

  testWidgets('reduced motion shows final values at once', (tester) async {
    useReducedMotion(tester);
    await tester.pumpWidget(
      dashboardApp(repo: demoRepository(), as: 'Anna Nowak'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('128'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('in-app Reduce motion switch also skips the count-up', (
    tester,
  ) async {
    final repo = demoRepository();
    await tester.pumpWidget(dashboardApp(repo: repo, as: 'Anna Nowak'));
    final container = containerOf(tester);
    container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(reduceMotion: true));
    await tester.pump();
    await tester.pump();
    expect(find.text('128'), findsOneWidget);
  });

  testWidgets('doctor: greeting, ready sentence, status feed', (tester) async {
    await pumpDashboard(tester, repo: demoRepository(), as: 'Dr Piotr Zając');

    expect(find.text('Good morning, Dr Zając'), findsOneWidget);
    expect(
      find.text('Doctor · Internal Medicine · 08:00–16:00'),
      findsOneWidget,
    );
    final repo = demoRepository();
    final ready = readyInDepartment(repo.current, 'INT');
    expect(ready, greaterThan(1));
    expect(find.text('$ready of your patients are ready'), findsOneWidget);
    expect(
      find.text('Ready for Discharge · Internal Medicine'),
      findsOneWidget,
    );
    expect(find.text('Recent status changes'), findsOneWidget);
    expect(find.text('Recent transfers'), findsNothing);
  });

  testWidgets('occupancy rows show % and Bottleneck / Full', (tester) async {
    await pumpDashboard(tester, repo: demoRepository());

    expect(find.text('Patients per department'), findsOneWidget);
    expect(find.text('128 of 210 beds'), findsOneWidget);
    expect(find.text('100% · Full'), findsOneWidget); // ICU 8/8
    expect(find.text('91% · Bottleneck'), findsOneWidget); // INT 29/32
    expect(find.text('43%'), findsOneWidget); // RAD 6/14
    expect(find.text('3 floors · '), findsNothing);
    expect(find.textContaining('2 bottlenecks', findRichText: true), findsOne);
    expect(find.text('ICU 100%'), findsOneWidget);
    expect(find.text('INT 91%'), findsOneWidget);

    // Floor filter: Floor 2 hides INT.
    await tester.tap(find.text('Floor 2'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('91% · Bottleneck'), findsNothing);
    expect(find.text('100% · Full'), findsOneWidget);
  });

  testWidgets('feed updates and highlights a simulated remote transfer', (
    tester,
  ) async {
    final repo = demoRepository();
    await pumpDashboard(tester, repo: repo);
    expect(
      tester
          .widgetList<WlActivityFeedItem>(find.byType(WlActivityFeedItem))
          .where((w) => w.live),
      isEmpty,
    );

    final evt = repo.simulateRemoteTransfer()!;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final p = repo.current.patient(evt.patientId)!;
    final live = tester
        .widgetList<WlActivityFeedItem>(find.byType(WlActivityFeedItem))
        .where((w) => w.live)
        .toList();
    expect(live, hasLength(1));
    expect(live.single.patientName, p.fullName);
    expect(live.single.highlightKey, evt.id);
    expect(live.single.timeAgo, 'now');
    // Transfers today counts the new one (count-up to 43).
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('43'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('KPIs follow a remote status change live, no reload', (
    tester,
  ) async {
    final repo = demoRepository();
    await pumpDashboard(tester, repo: repo);
    List<String> kpiTexts() => [
      for (final c in tester.widgetList<WlKpiCard>(find.byType(WlKpiCard)))
        '${c.label}=${c.value}',
    ];
    expect(kpiTexts(), [
      'Total patients=128',
      'In treatment=54',
      'Ready for discharge=17',
      'Transfers today=42',
    ]);

    final evt = repo.simulateRemoteStatus()!;
    final expected = DashboardStats.from(repo.current, demoNow).kpis;
    await tester.pump();
    // Still the same screen: no skeleton, no intro replay.
    expect(find.byType(WlSkeleton), findsNothing);
    expect(kpiTexts(), [for (final k in expected) '${k.label}=${k.value}']);
    // In treatment or Ready for discharge moved by exactly one.
    final changed = evt.to == PatientStatus.inTreatment
        ? 'In treatment=55'
        : 'Ready for discharge=18';
    expect(kpiTexts(), contains(changed));
    // The live count-up (380ms) lands on the new value.
    await tester.pump(const Duration(milliseconds: 400));
    final [label, value] = changed.split('=');
    expect(
      find.descendant(
        of: find.byKey(ValueKey(label)),
        matching: find.text(value),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('offline: banner, Offline pill, cached KPIs', (tester) async {
    final repo = demoRepository();
    await pumpDashboard(tester, repo: repo);
    final container = containerOf(tester);
    final synced = hm(container.read(connectivityProvider).syncedAt);

    await container.read(connectivityProvider.notifier).setOnline(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.byType(WlOfflineBanner), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Synced $synced'), findsNWidgets(4));
    expect(find.text('128'), findsOneWidget);
    // Quick actions stay (reading is allowed offline).
    expect(find.text('Scan NFC'), findsOneWidget);
  });

  testWidgets('loading: skeleton KPIs, quick actions live', (tester) async {
    await pumpDashboard(tester, repo: EmptyHospitalRepository());

    expect(find.text('Scan NFC'), findsOneWidget);
    expect(find.text('Search patient'), findsOneWidget);
    final cards = tester.widgetList<WlKpiCard>(find.byType(WlKpiCard));
    expect(cards, hasLength(4));
    expect(cards.every((c) => c.loading), isTrue);
    expect(find.text('Patients per department'), findsNothing);
  });

  testWidgets('bell opens notifications; unread dot is announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpDashboard(tester, repo: demoRepository());
    expect(
      find.bySemanticsLabel(RegExp(r'^Notifications, \d+ unread$')),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel(RegExp('^Notifications')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(NotificationsScreen), findsOneWidget);
    handle.dispose();
  });

  testWidgets('stagger plays once: no replay when returning to the tab', (
    tester,
  ) async {
    await pumpDashboard(tester, repo: demoRepository());
    final nav = find.byType(WlBottomNav);
    await tester.tap(find.descendant(of: nav, matching: find.text('History')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.descendant(of: nav, matching: find.text('Dashboard')),
    );
    await tester.pump();
    // Still the final value on the very first frame back.
    expect(find.text('128'), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('text scale 2.0: nurse and doctor without overflow', (
    tester,
  ) async {
    for (final who in ['Anna Nowak', 'Dr Piotr Zając', 'Katarzyna Wilk']) {
      await pumpDashboard(
        tester,
        repo: demoRepository(),
        as: who,
        textScale: 2,
        size: const Size(390, 5200),
      );
      expect(tester.takeException(), isNull, reason: who);
      expect(find.text('128'), findsOneWidget);
    }
  });

  test('stats match the design totals', () {
    final repo = demoRepository();
    final s = DashboardStats.from(repo.current, demoNow);
    expect(s.kpis.map((k) => k.value), [128, 54, 17, 42]);
    expect(s.patients, 128);
    expect(s.beds, 210);
    expect(s.bottlenecks.map((d) => d.code), ['ICU', 'INT']);
    expect(s.bottlenecks.map((d) => d.flag), ['Full', 'Bottleneck']);
    for (final k in s.kpis) {
      expect(k.trend, hasLength(DashboardStats.trendPoints));
      expect(k.trend.last, k.value.toDouble());
    }
    expect(greetingFor(demoNow), 'Good morning');
  });
}

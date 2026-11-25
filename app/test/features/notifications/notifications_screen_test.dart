import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/notifications/application/notifications.dart';
import 'package:wardline/features/notifications/presentation/notifications_screen.dart';

import '../../helpers/harness.dart';
import '../dashboard/dashboard_test_utils.dart';

Future<void> openNotifications(
  WidgetTester tester, {
  String as = 'Anna Nowak',
  double textScale = 1,
  void Function(dynamic repo)? before,
}) async {
  final repo = demoRepository();
  before?.call(repo);
  await pumpDashboard(
    tester,
    repo: repo,
    as: as,
    textScale: textScale,
    size: const Size(390, 1400),
  );
  unawaited(
    containerOf(tester).read(routerProvider).push(Routes.notifications),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  test('nurse: admissions and ward discharges, never own', () {
    final repo = demoRepository();
    final anna = staff(repo, 'Anna Nowak');
    final list = deriveNotifications(
      repo.current,
      anna,
      const AppSettings(),
      demoNow,
    );
    expect(list, isNotEmpty);
    expect(
      list.map((n) => n.kind).toSet(),
      everyElement(
        isIn([
          NotificationKind.admission,
          NotificationKind.readyForDischarge,
          NotificationKind.discharged,
        ]),
      ),
    );
    final byId = {for (final e in repo.current.events) e.id: e};
    for (final n in list) {
      expect(byId[n.id]!.byName, isNot('Anna Nowak'));
    }
    for (final n in list.where((n) => n.kind != NotificationKind.admission)) {
      expect(repo.current.patient(n.patientId)!.location, 'INT');
    }
  });

  test('doctor: arrivals in / departures from the ward, status changes', () {
    final repo = demoRepository();
    final doc = staff(repo, 'Dr Piotr Zając');
    final list = deriveNotifications(
      repo.current,
      doc,
      const AppSettings(),
      demoNow,
    );
    expect(list, isNotEmpty);
    expect(
      list.map((n) => n.kind).toSet(),
      everyElement(
        isIn([
          NotificationKind.arrived,
          NotificationKind.left,
          NotificationKind.statusChanged,
        ]),
      ),
    );
    final byId = {for (final e in repo.current.events) e.id: e};
    expect(list.any((n) => byId[n.id]!.byName == doc.name), isFalse);
    for (final n in list.where((n) => n.kind == NotificationKind.arrived)) {
      expect((byId[n.id]! as LocationEvent).to, 'INT');
    }
  });

  test('settings switches turn kinds off; admin gets none', () {
    final repo = demoRepository();
    final doc = staff(repo, 'Dr Piotr Zając');
    final noStatus = deriveNotifications(
      repo.current,
      doc,
      const AppSettings(notifyStatus: false),
      demoNow,
    );
    expect(
      noStatus.where((n) => n.kind == NotificationKind.statusChanged),
      isEmpty,
    );
    expect(
      deriveNotifications(
        repo.current,
        staff(repo, 'Katarzyna Wilk'),
        const AppSettings(),
        demoNow,
      ),
      isEmpty,
    );
  });

  testWidgets('nurse screen: scope line, unread rows, mark all read', (
    tester,
  ) async {
    await openNotifications(tester);
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(
      find.text('For nurses: admissions & discharges · Internal Medicine'),
      findsOneWidget,
    );
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Arrived in your ward'), findsNothing);

    final c = containerOf(tester);
    expect(c.read(unreadNotificationCountProvider), greaterThan(0));
    await tester.tap(find.text('Mark all read'));
    await tester.pump();
    expect(c.read(unreadNotificationCountProvider), 0);
    expect(find.text('Mark all read'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Your own changes never notify you.'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(NotificationsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Your own changes never notify you.'), findsOneWidget);
  });

  testWidgets('doctor screen shows ward arrivals and status changes', (
    tester,
  ) async {
    await openNotifications(tester, as: 'Dr Piotr Zając');
    expect(
      find.text('For doctors: arrivals in Internal Medicine, status changes'),
      findsOneWidget,
    );
    expect(
      find.text('Arrived in your ward').evaluate().length +
          find.text('Status changed').evaluate().length +
          find.text('Left your ward').evaluate().length,
      greaterThan(0),
    );
    expect(find.text('New admission'), findsNothing);
  });

  testWidgets('a remote arrival in the ward appears unread', (tester) async {
    await openNotifications(tester, as: 'Dr Piotr Zając');
    final c = containerOf(tester);
    final before = c.read(unreadNotificationCountProvider);
    final repo = c.read(demoRepositoryProvider)!;
    final p = repo.current.patients.firstWhere(
      (p) => p.location == 'RAD' && p.status != PatientStatus.discharged,
    );
    repo.simulateRemoteTransfer(patientId: p.id, to: 'INT');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.read(unreadNotificationCountProvider), before + 1);
    expect(find.textContaining('${p.fullName} ← Radiology'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('admin: empty state', (tester) async {
    await openNotifications(tester, as: 'Katarzyna Wilk');
    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.text('Notification settings'), findsOneWidget);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('everything switched off: empty state names the ward', (
    tester,
  ) async {
    final repo = demoRepository();
    await pumpDashboard(tester, repo: repo, size: const Size(390, 900));
    final c = containerOf(tester);
    c
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(notifyArrivals: false, notifyDischarges: false),
        );
    unawaited(c.read(routerProvider).push(Routes.notifications));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("You're all caught up"), findsOneWidget);
    expect(
      find.text(
        'New admissions and discharges in Internal Medicine will show up here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('text scale 2.0 without overflow', (tester) async {
    for (final who in ['Anna Nowak', 'Dr Piotr Zając', 'Katarzyna Wilk']) {
      await openNotifications(tester, as: who, textScale: 2);
      expect(tester.takeException(), isNull, reason: who);
    }
  });
}

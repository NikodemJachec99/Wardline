import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/core/theme/wl_tokens.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/features/admin/presentation/admin_screen.dart';
import 'package:wardline/features/auth/presentation/login_screen.dart';
import 'package:wardline/features/profile/presentation/profile_screen.dart';

import '../history/history_harness.dart';

Finder get _list => find
    .descendant(
      of: find.byType(ProfileScreen),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 150, scrollable: _list);
  await tester.pump();
}

void main() {
  testWidgets('shows who is signed in, role label and shift', (tester) async {
    phone(tester);
    await pumpApp(tester, repo: clockedRepository(), location: Routes.profile);

    expect(find.text('Anna Nowak'), findsOneWidget);
    expect(find.text('Nurse · Internal Medicine'), findsOneWidget);
    expect(
      find.text('Day shift 07:00–19:00 · ends in 8 h 14 min'),
      findsOneWidget,
    );
    // Not an admin: no Admin entry.
    expect(find.text('Staff, roles and wristband tags'), findsNothing);
  });

  testWidgets('doctor sees the doctor role label', (tester) async {
    phone(tester);
    await pumpApp(
      tester,
      repo: clockedRepository(),
      as: 'Dr Piotr Zając',
      location: Routes.profile,
    );
    expect(find.text('Doctor · Internal Medicine'), findsOneWidget);
    expect(find.text('Shift 08:00–16:00 · ends in 5 h 14 min'), findsOne);
  });

  testWidgets('Reduce motion switch turns on reduced motion app-wide', (
    tester,
  ) async {
    phone(tester);
    final container = await pumpApp(
      tester,
      repo: clockedRepository(),
      location: Routes.profile,
    );
    BuildContext ctx() => tester.element(find.text('Anna Nowak'));
    expect(WlMotion.reduced(ctx()), isFalse);

    await tester.tap(find.text('Reduce motion'));
    await settle(tester);
    expect(container.read(settingsProvider).reduceMotion, isTrue);
    expect(WlMotion.reduced(ctx()), isTrue);
    expect(
      find.text('On · fades instead of slides, no shimmer'),
      findsOneWidget,
    );

    await tester.tap(find.text('Reduce motion'));
    await settle(tester);
    expect(WlMotion.reduced(ctx()), isFalse);
  });

  testWidgets('notification and haptics switches update settings', (
    tester,
  ) async {
    phone(tester);
    final container = await pumpApp(
      tester,
      repo: clockedRepository(),
      location: Routes.profile,
    );
    await tester.tap(find.text('Haptics'));
    await _scrollTo(tester, find.text('Status changes'));
    await tester.tap(find.text('Status changes'));
    await settle(tester);
    final s = container.read(settingsProvider);
    expect(s.haptics, isFalse);
    expect(s.notifyStatus, isFalse);
  });

  testWidgets('Admin entry only for admins and opens the admin area', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(
      tester,
      repo: clockedRepository(),
      as: 'Katarzyna Wilk',
      location: Routes.profile,
    );
    expect(find.text('Admin'), findsWidgets);
    await _scrollTo(tester, find.text('Staff, roles and wristband tags'));
    await tester.tap(find.text('Staff, roles and wristband tags'));
    await settle(tester);
    expect(find.byType(AdminScreen), findsOneWidget);
  });

  testWidgets('demo role switch signs in as another role', (tester) async {
    phone(tester);
    final container = await pumpApp(
      tester,
      repo: clockedRepository(),
      location: Routes.profile,
    );
    await _scrollTo(tester, find.text('Sign in as'));
    await tester.tap(find.text('Doctor'));
    await settle(tester);
    expect(container.read(sessionProvider)?.role, UserRole.doctor);
    await tester.scrollUntilVisible(
      find.text('Doctor · Internal Medicine'),
      -150,
      scrollable: _list,
    );
    expect(find.text('Doctor · Internal Medicine'), findsOneWidget);
  });

  testWidgets('demo offline switch shows the offline banner', (tester) async {
    phone(tester);
    final container = await pumpApp(
      tester,
      repo: clockedRepository(),
      location: Routes.profile,
    );
    await _scrollTo(tester, find.text('Simulate offline'));
    await tester.tap(find.text('Simulate offline'));
    await settle(tester);
    expect(container.read(connectivityProvider).online, isFalse);
    await tester.scrollUntilVisible(
      find.byType(WlOfflineBanner),
      -150,
      scrollable: _list,
    );
    expect(find.text("You're offline"), findsOneWidget);

    // Back online through the same switch: reconnect + full refetch.
    await _scrollTo(tester, find.text('Simulate offline'));
    await tester.tap(find.text('Simulate offline'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(connectivityProvider).online, isTrue);
    expect(container.read(connectivityProvider).backOnlineAt, isNotNull);
    await tester.scrollUntilVisible(
      find.textContaining('Back online'),
      -150,
      scrollable: _list,
    );
    await drainTimers(tester);
  });

  testWidgets('Sign out returns to sign in', (tester) async {
    phone(tester);
    final container = await pumpApp(
      tester,
      repo: clockedRepository(),
      location: Routes.profile,
    );
    await _scrollTo(tester, find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await settle(tester);
    expect(container.read(sessionProvider), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('text scale 2.0 renders without overflow', (tester) async {
    phone(tester, textScale: 2);
    await pumpApp(tester, repo: clockedRepository(), location: Routes.profile);
    expect(tester.takeException(), isNull);
    await _scrollTo(tester, find.text('Sign out'));
    expect(tester.takeException(), isNull);
  });
}

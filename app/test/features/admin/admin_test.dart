import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/router.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/core/widgets/wl/wl.dart';
import 'package:wardline/data/demo/demo_hospital_repository.dart';
import 'package:wardline/domain/failures.dart';
import 'package:wardline/domain/models.dart';
import 'package:wardline/features/admin/presentation/admin_screen.dart';
import 'package:wardline/features/admin/presentation/demo_mode_screen.dart';
import 'package:wardline/features/admin/presentation/print_cards_screen.dart';
import 'package:wardline/features/admin/presentation/program_tag_screen.dart';
import 'package:wardline/features/dashboard/presentation/dashboard_screen.dart';

import '../../helpers/harness.dart';
import '../dashboard/dashboard_test_utils.dart';

/// Signs in as [as] and pushes [route].
Future<DemoHospitalRepository> openRoute(
  WidgetTester tester,
  String route, {
  String as = 'Katarzyna Wilk',
  double textScale = 1,
  Size size = const Size(390, 1300),
}) async {
  final repo = demoRepository();
  await pumpDashboard(
    tester,
    repo: repo,
    as: as,
    textScale: textScale,
    size: size,
  );
  unawaited(containerOf(tester).read(routerProvider).push(route));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return repo;
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('Admin', () {
    testWidgets('non-admin is redirected to the dashboard', (tester) async {
      for (final who in ['Anna Nowak', 'Dr Piotr Zając']) {
        await openRoute(tester, Routes.admin, as: who);
        expect(find.byType(AdminScreen), findsNothing, reason: who);
        expect(find.byType(DashboardScreen), findsOneWidget);
        await openRoute(tester, Routes.demo, as: who);
        expect(find.byType(DemoModeScreen), findsNothing, reason: who);
      }
    });

    testWidgets('staff list with role labels; own role read-only', (
      tester,
    ) async {
      await openRoute(tester, Routes.admin);
      expect(find.byType(AdminScreen), findsOneWidget);
      expect(find.text('Katarzyna Wilk · You'), findsOneWidget);
      expect(find.text("Your role can't be changed by you"), findsOneWidget);
      expect(find.text('Anna Nowak'), findsOneWidget);
      expect(find.text('Dr Piotr Zając'), findsOneWidget);
      expect(find.text('Nurse'), findsNWidgets(3));
      expect(find.text('Doctor'), findsNWidgets(2));
      expect(find.text('Admin'), findsWidgets);

      // Own row opens nothing.
      await tester.tap(find.text('Katarzyna Wilk · You'));
      await settle(tester);
      expect(find.byType(RoleSheet), findsNothing);

      // Search filters by name or email.
      await tester.enterText(find.byType(TextField), 'zajac');
      await settle(tester);
      expect(find.text('Dr Piotr Zając'), findsOneWidget);
      expect(find.text('Anna Nowak'), findsNothing);
    });

    testWidgets('role sheet: Current marked, save after the round trip', (
      tester,
    ) async {
      await openRoute(tester, Routes.admin);
      await tester.tap(find.text('Marek Kowal'));
      await settle(tester);
      expect(find.byType(RoleSheet), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Can transfer patients'), findsOneWidget);
      expect(find.textContaining('Simulation'), findsOneWidget);

      // Unchanged role: Save is not available yet (invalid form).
      final save = tester.widget<WlButton>(
        find.widgetWithText(WlButton, 'Save role'),
      );
      expect(save.onPressed, isNull);

      await tester.tap(find.text('Can change status'));
      await tester.pump();
      await tester.tap(find.text('Save role'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      // Not saved before the answer.
      expect(find.byType(RoleSheet), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(find.byType(RoleSheet), findsNothing);
      expect(find.text('Marek Kowal is now Doctor'), findsOneWidget);
      expect(find.text('Doctor'), findsNWidgets(3));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Program NFC tag: patient → write → verify (simulation)', (
      tester,
    ) async {
      final repo = await openRoute(tester, Routes.admin);
      await tester.tap(find.text('Program NFC tag'));
      await settle(tester);
      expect(find.byType(ProgramTagScreen), findsOneWidget);
      expect(find.textContaining('Simulation: no tag is written'), findsOne);
      expect(find.text('Choose the patient for this wristband'), findsOne);

      final p = repo.current.patients.firstWhere(
        (p) => p.code == 'HPT-4QW8N2KD',
        orElse: () => repo.current.patients.first,
      );
      await tester.enterText(find.byType(TextField), p.code);
      await settle(tester);
      await tester.tap(find.text('${p.fullName}, ${p.age}'));
      await settle(tester);
      expect(find.text('Hold a blank wristband to the phone'), findsOneWidget);

      await tester.tap(find.text('Start writing'));
      await tester.pump();
      expect(find.text('Writing…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await settle(tester);
      expect(find.text('Wristband ready'), findsOneWidget);
      expect(find.text('Read back and matched.'), findsOneWidget);
      expect(find.text(p.code), findsNWidgets(2));
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.byType(ProgramTagScreen), findsNothing);
    });

    testWidgets('Print cards: preview, selection count, simulated print', (
      tester,
    ) async {
      await openRoute(tester, Routes.admin);
      await tester.tap(find.text('Print cards & QR'));
      await settle(tester);
      expect(find.byType(PrintCardsScreen), findsOneWidget);
      expect(find.text('WARDLINE'), findsOneWidget);
      expect(find.text('PATIENTS · 3 SELECTED'), findsOneWidget);
      await tester.tap(find.text('Print 3 cards'));
      await tester.pump();
      expect(find.text('Simulation · nothing was printed'), findsOneWidget);
      await tester.tap(find.text('Wristband label'));
      await tester.pump();
      expect(find.text('Print 3 labels'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Showcase tile opens demo mode', (tester) async {
      await openRoute(tester, Routes.admin);
      await tester.tap(find.text('Showcase'));
      await settle(tester);
      expect(find.byType(DemoModeScreen), findsOneWidget);
    });
  });

  group('Demo mode', () {
    testWidgets('conflict and timeout arm the next write', (tester) async {
      final repo = await openRoute(tester, Routes.demo);
      expect(find.text('Showcase'), findsOneWidget);
      expect(find.text('Admin only'), findsOneWidget);
      expect(repo.knobs.conflictNext, isFalse);

      await tester.tap(find.bySemanticsLabel('Run Conflict'));
      await tester.pump();
      expect(repo.knobs.conflictNext, isTrue);
      expect(
        find.text('Armed · confirm any transfer or status change'),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Stop Conflict'));
      await tester.pump();
      expect(repo.knobs.conflictNext, isFalse);

      await tester.tap(find.bySemanticsLabel('Run Timeout'));
      await tester.pump();
      expect(repo.knobs.timeoutNext, isTrue);
      expect(find.text('Armed · the next change times out'), findsOneWidget);

      // A write consumes the knob; the row goes back to idle.
      final anna = staff(repo, 'Anna Nowak');
      final p = repo.current.patients.firstWhere(
        (p) => p.status != PatientStatus.discharged && p.location != 'RAD',
      );
      Object? error;
      unawaited(
        repo
            .transferPatient(
              patientId: p.id,
              to: 'RAD',
              expectedVersion: p.version,
              requestId: 'req-1',
              by: anna,
            )
            .then<void>((_) {}, onError: (Object e) => error = e),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(error, isA<TimeoutFailure>());
      await tester.pump();
      expect(repo.knobs.timeoutNext, isFalse);
      expect(find.text('Armed · the next change times out'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('one-shot remote transfer and status change', (tester) async {
      final repo = await openRoute(tester, Routes.demo);
      final before = repo.current.events.length;
      await tester.tap(find.bySemanticsLabel("Run Another nurse's transfer"));
      await tester.pump();
      expect(repo.current.events.length, before + 1);
      expect(repo.current.lastRemoteEvent, isA<LocationEvent>());
      expect(repo.current.lastRemoteEvent!.byName, isNot('Anna Nowak'));

      await tester.tap(find.bySemanticsLabel("Run A doctor's status change"));
      await tester.pump();
      expect(repo.current.lastRemoteEvent, isA<StatusEvent>());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('live transfers run every 20 s until stopped', (tester) async {
      final repo = await openRoute(tester, Routes.demo);
      final before = repo.current.events.length;
      await tester.tap(find.bySemanticsLabel('Run Live transfers'));
      await tester.pump();
      expect(repo.current.events.length, before + 1);
      expect(find.text('Running · 1 transfer sent'), findsOneWidget);

      await tester.pump(const Duration(seconds: 20));
      expect(repo.current.events.length, before + 2);
      expect(find.text('Running · 2 transfers sent'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Stop Live transfers'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 25));
      expect(repo.current.events.length, before + 2);
    });

    testWidgets('live timer stops when the screen closes', (tester) async {
      final repo = await openRoute(tester, Routes.demo);
      await tester.tap(find.bySemanticsLabel('Run Live transfers'));
      await tester.pump();
      final after = repo.current.events.length;
      containerOf(tester).read(routerProvider).pop();
      await settle(tester);
      expect(find.byType(DemoModeScreen), findsNothing);
      await tester.pump(const Duration(seconds: 45));
      expect(repo.current.events.length, after);
    });

    testWidgets('offline scenario: countdown, remote rows need a connection', (
      tester,
    ) async {
      await openRoute(tester, Routes.demo);
      final c = containerOf(tester);
      await tester.tap(find.bySemanticsLabel('Run Offline'));
      await tester.pump();
      expect(c.read(connectivityProvider).online, isFalse);
      expect(find.text('Offline for 1:00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      expect(find.text('Offline for 0:52'), findsOneWidget);
      expect(find.text('Needs a connection'), findsNWidgets(3));

      await tester.tap(find.bySemanticsLabel('Stop Offline'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(c.read(connectivityProvider).online, isTrue);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('offline scenario ends by itself after 60 s', (tester) async {
      await openRoute(tester, Routes.demo);
      final c = containerOf(tester);
      await tester.tap(find.bySemanticsLabel('Run Offline'));
      await tester.pump();
      for (var i = 0; i < 61; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(seconds: 1));
      expect(c.read(connectivityProvider).online, isTrue);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  testWidgets('text scale 2.0: admin, demo, tag, print without overflow', (
    tester,
  ) async {
    await openRoute(
      tester,
      Routes.admin,
      textScale: 2,
      size: const Size(390, 2600),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Marek Kowal'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    await openRoute(
      tester,
      Routes.demo,
      textScale: 2,
      size: const Size(390, 3000),
    );
    await tester.tap(find.bySemanticsLabel('Run Conflict'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await openRoute(
      tester,
      Routes.admin,
      textScale: 2,
      size: const Size(390, 2600),
    );
    await tester.tap(find.text('Program NFC tag'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(InkWell).at(1));
    await settle(tester);
    expect(tester.takeException(), isNull);

    await openRoute(
      tester,
      Routes.admin,
      textScale: 2,
      size: const Size(390, 2600),
    );
    await tester.tap(find.text('Print cards & QR'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}

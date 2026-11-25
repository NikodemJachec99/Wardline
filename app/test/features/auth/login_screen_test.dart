import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/state/providers.dart';
import 'package:wardline/features/auth/presentation/login_screen.dart';
import 'package:wardline/features/dashboard/presentation/dashboard_screen.dart';

import '../history/history_harness.dart';

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

Future<void> _type(WidgetTester tester, String email, String password) async {
  await tester.enterText(_field('Work email'), email);
  await tester.enterText(_field('Password'), password);
  await tester.pump();
}

void main() {
  testWidgets('signed out lands on sign in with the simulation note', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(tester, repo: clockedRepository(), as: null);
    await settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Wardline'), findsOneWidget);
    expect(find.text('Simulation · fictional data'), findsOneWidget);
    expect(find.text('Forgot your password? Ask your ward admin.'), findsOne);
  });

  testWidgets('correct demo credentials sign in and open the dashboard', (
    tester,
  ) async {
    phone(tester);
    final container = await pumpApp(
      tester,
      repo: clockedRepository(),
      as: null,
    );
    await settle(tester);
    await _type(tester, 'anna.nowak@wardline.test', 'wardline');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    // Locked while the request is in flight; a second tap is ignored.
    expect(find.text('Signing in…'), findsOneWidget);
    final field = tester.widget<TextField>(_field('Work email'));
    expect(field.enabled, isFalse);
    await tester.tap(find.text('Signing in…'));

    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(container.read(sessionProvider)?.name, 'Anna Nowak');
  });

  testWidgets('wrong password shows the inline error', (tester) async {
    phone(tester);
    final container = await pumpApp(
      tester,
      repo: clockedRepository(),
      as: null,
    );
    await settle(tester);
    await _type(tester, 'anna.nowak@wardline.test', 'nope');
    await tester.tap(find.text('Sign in'));
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(container.read(sessionProvider), isNull);

    // Typing again clears the error.
    await tester.enterText(_field('Password'), 'wardline');
    await tester.pump();
    expect(find.text('Email or password is incorrect.'), findsNothing);
  });

  testWidgets('offline shows the no-connection error', (tester) async {
    phone(tester);
    final container = await pumpApp(
      tester,
      repo: clockedRepository(),
      as: null,
    );
    await settle(tester);
    await container.read(connectivityProvider.notifier).setOnline(false);
    await _type(tester, 'anna.nowak@wardline.test', 'wardline');
    await tester.tap(find.text('Sign in'));
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.textContaining('Signing in needs a connection'), findsOne);
    expect(container.read(sessionProvider), isNull);
  });

  testWidgets('demo account chips fill the form', (tester) async {
    phone(tester);
    await pumpApp(tester, repo: clockedRepository(), as: null);
    await settle(tester);
    await tester.ensureVisible(find.text('Doctor'));
    await tester.tap(find.text('Doctor'));
    await tester.pump();
    expect(
      tester.widget<TextField>(_field('Work email')).controller!.text,
      'piotr.zajac@wardline.test',
    );
    expect(
      tester.widget<TextField>(_field('Password')).controller!.text,
      'wardline',
    );
  });

  testWidgets('password visibility toggles', (tester) async {
    phone(tester);
    await pumpApp(tester, repo: clockedRepository(), as: null);
    await settle(tester);
    expect(tester.widget<TextField>(_field('Password')).obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(tester.widget<TextField>(_field('Password')).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('autofill hints are set', (tester) async {
    phone(tester);
    await pumpApp(tester, repo: clockedRepository(), as: null);
    await settle(tester);
    expect(
      tester.widget<TextField>(_field('Work email')).autofillHints,
      contains(AutofillHints.username),
    );
    expect(
      tester.widget<TextField>(_field('Password')).autofillHints,
      contains(AutofillHints.password),
    );
  });

  testWidgets('text scale 2.0 scrolls without overflow', (tester) async {
    phone(tester, textScale: 2);
    await pumpApp(tester, repo: clockedRepository(), as: null);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}

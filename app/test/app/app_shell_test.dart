import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/app.dart';

void main() {
  testWidgets('shows five tabs and switches between them', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WardlineApp()));
    await tester.pumpAndSettle();

    final Finder navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget);
    for (final String label in <String>[
      'Dashboard',
      'Pacjenci',
      'Skanuj',
      'Historia',
      'Profil',
    ]) {
      expect(
        find.descendant(of: navBar, matching: find.text(label)),
        findsOneWidget,
      );
    }

    await tester.tap(
      find.descendant(of: navBar, matching: find.text('Pacjenci')),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Pacjenci'), findsOneWidget);
  });
}

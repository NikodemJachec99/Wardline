import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/app.dart';
import 'package:wardline/core/widgets/wl/wl.dart';

void main() {
  testWidgets('WlBottomNav shows five English tabs and switches', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: WardlineApp()));
    await tester.pumpAndSettle();

    final nav = find.byType(WlBottomNav);
    expect(nav, findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    for (final label in [
      'Dashboard',
      'Patients',
      'Scan',
      'History',
      'Profile',
    ]) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
      );
    }

    await tester.tap(find.descendant(of: nav, matching: find.text('Patients')));
    await tester.pumpAndSettle();
    expect(tester.widget<WlBottomNav>(nav).currentIndex, 1);
  });

  testWidgets('Scan tab has an accessible label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const ProviderScope(child: WardlineApp()));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Scan wristband or QR code'), findsOneWidget);
    handle.dispose();
  });
}

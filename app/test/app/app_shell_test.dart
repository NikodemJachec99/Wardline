import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/core/widgets/wl/wl.dart';

import '../helpers/harness.dart';

void main() {
  testWidgets('WlBottomNav shows five English tabs and switches', (
    tester,
  ) async {
    await tester.pumpWidget(appHarness(repo: demoRepository()));
    // No pumpAndSettle: the dashboard's live pulse loops (motion.md).
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

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

    await tester.tap(find.descendant(of: nav, matching: find.text('History')));
    // No pumpAndSettle: the dashboard's live pulse loops (motion.md).
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<WlBottomNav>(nav).currentIndex, 3);
  });

  testWidgets('Scan tab has an accessible label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(appHarness(repo: demoRepository()));
    // No pumpAndSettle: the dashboard's live pulse loops (motion.md).
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.bySemanticsLabel('Scan wristband or QR code'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('signed out goes to sign in', (tester) async {
    await tester.pumpWidget(appHarness(repo: demoRepository(), as: null));
    await tester.pumpAndSettle();
    expect(find.byType(WlBottomNav), findsNothing);
  });
}

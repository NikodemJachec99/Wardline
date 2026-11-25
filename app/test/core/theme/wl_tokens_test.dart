import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:wardline/app/theme.dart';
import 'package:wardline/core/theme/wl_tokens.dart';
import 'package:wardline/core/widgets/wl/wl_status_chip.dart';

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: buildTheme(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('WlTokens unit and design system tokens (PLAN.md §7.1)', () {
    test('is registered on the app theme with correct color scheme', () {
      final ThemeData theme = buildTheme();
      final tokens = theme.extension<WlTokens>();
      expect(tokens, isNotNull);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFBFC));
      expect(theme.colorScheme.primary, const Color(0xFF0A7F85));
      expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onSurface, const Color(0xFF0F1720));
      expect(theme.dividerColor, const Color(0xFFE4E8EE));
    });

    test('PLAN §7.1 core colors and aliases match specifications', () {
      const WlColors c = WlColors();
      // Primary teal
      expect(c.primary, const Color(0xFF0E9FA6));
      expect(c.primaryPressed, const Color(0xFF0B858B));
      // Backgrounds and surfaces
      expect(c.bg, const Color(0xFFFAFBFC));
      expect(c.page, const Color(0xFFFAFBFC));
      expect(c.surface, const Color(0xFFFFFFFF));
      expect(c.surface2, const Color(0xFFF3F5F8));
      expect(c.subtle, const Color(0xFFF3F5F8));
      // Borders
      expect(c.border, const Color(0xFFE4E8EE));
      expect(c.borderStrong, const Color(0xFFCBD2DB));
      // Text
      expect(c.text, const Color(0xFF0F1720));
      expect(c.textSecondary, const Color(0xFF5B6675));
      expect(c.textMuted, const Color(0xFF5B6675));
      expect(c.textDisabled, const Color(0xFF9AA3AF));
      // Status direct colors
      expect(c.statusAdmitted, const Color(0xFF2F6FEB));
      expect(c.statusInTreatment, const Color(0xFF7C4DDB));
      expect(c.statusReadyForDischarge, const Color(0xFF14A35B));
      expect(c.statusDischarged, const Color(0xFF8A94A3));
      // Heatmap direct colors
      expect(c.heatLow, const Color(0xFF22B573));
      expect(c.heatMedium, const Color(0xFFF29A2E));
      expect(c.heatHigh, const Color(0xFFE5484D));
    });

    test('spacing tokens match PLAN §7.1 and touch targets', () {
      const WlSpace sp = WlSpace();
      expect(sp.xxs, 4.0);
      expect(sp.xs, 8.0);
      expect(sp.sm, 12.0);
      expect(sp.md, 16.0);
      expect(sp.lg, 24.0);
      expect(sp.xl, 32.0);
      expect(sp.xxl, 48.0);
      expect(sp.touchMin, 48.0);
      expect(sp.action, 56.0);
    });

    test('radii tokens match PLAN §7.1', () {
      const WlRadius r = WlRadius();
      expect(r.chip, 8.0);
      expect(r.input, 12.0);
      expect(r.card, 16.0);
      expect(r.sheet, 24.0);
      expect(r.full, 999.0);
      expect(r.chipBr, BorderRadius.circular(8));
      expect(r.inputBr, BorderRadius.circular(12));
      expect(r.cardBr, BorderRadius.circular(16));
      expect(r.sheetBr, const BorderRadius.vertical(top: Radius.circular(24)));
    });

    test('status styles match the design system with icon and label', () {
      const WlColors c = WlColors();

      final admitted = c.status(PatientStatus.admitted);
      expect(admitted.base, const Color(0xFF2F6FEB));
      expect(admitted.label, 'Admitted');
      expect(admitted.shortLabel, 'Admitted');
      expect(admitted.lucideIcon, 'log-in');

      final inTreatment = c.status(PatientStatus.inTreatment);
      expect(inTreatment.base, const Color(0xFF7C4DDB));
      expect(inTreatment.label, 'In Treatment');
      expect(inTreatment.shortLabel, 'In Treatment');
      expect(inTreatment.lucideIcon, 'activity');

      final ready = c.status(PatientStatus.readyForDischarge);
      expect(ready.base, const Color(0xFF14A35B));
      expect(ready.label, 'Ready for Discharge');
      expect(ready.shortLabel, 'Ready');
      expect(ready.lucideIcon, 'circle-check');

      final discharged = c.status(PatientStatus.discharged);
      expect(discharged.base, const Color(0xFF8A94A3));
      expect(discharged.label, 'Discharged');
      expect(discharged.shortLabel, 'Discharged');
      expect(discharged.lucideIcon, 'log-out');
    });

    test('occupancy thresholds: <60 low, 60–85 medium, >85 high with word', () {
      const WlColors c = WlColors();
      final low = c.occupancy(59);
      expect(low.level, OccupancyLevel.low);
      expect(low.fill, const Color(0xFF22B573));
      expect(low.word, 'Low');

      final medMin = c.occupancy(60);
      expect(medMin.level, OccupancyLevel.medium);
      expect(medMin.fill, const Color(0xFFF29A2E));
      expect(medMin.word, 'Medium');

      final medMax = c.occupancy(85);
      expect(medMax.level, OccupancyLevel.medium);
      expect(medMax.fill, const Color(0xFFF29A2E));
      expect(medMax.word, 'Medium');

      final high = c.occupancy(86);
      expect(high.level, OccupancyLevel.high);
      expect(high.fill, const Color(0xFFE5484D));
      expect(high.word, 'High');
    });

    test('motion tokens match PLAN §7.1', () {
      const WlMotionTokens m = WlMotionTokens();
      expect(m.fast, const Duration(milliseconds: 120));
      expect(m.base, const Duration(milliseconds: 220));
      expect(m.slow, const Duration(milliseconds: 380));
      expect(m.out, Curves.easeOutCubic);
      expect(m.sheetSpring.damping, 38);
      expect(m.sheetSpring.stiffness, 420);
    });

    test('typography tokens have Inter family and correct sizing', () {
      const WlType t = WlType();
      expect(WlType.family, 'Inter');
      expect(t.display.fontSize, 34);
      expect(t.title1.fontSize, 28);
      expect(t.title2.fontSize, 22);
      expect(t.title3.fontSize, 18);
      expect(t.body.fontSize, 16);
      expect(t.label.fontSize, 16);
      expect(t.callout.fontSize, 15);
      expect(t.subhead.fontSize, 14);
      expect(t.caption.fontSize, 12);
      expect(t.overline.fontSize, 11);
      expect(t.kpi.fontSize, 32);
    });
  });

  group('ThemeData widget tests', () {
    testWidgets(
      'Theme.of(context) provides WlTokens extension in widget tree',
      (tester) async {
        late WlTokens tokens;
        await tester.pumpWidget(
          _testApp(
            Builder(
              builder: (context) {
                tokens = WlTokens.of(context);
                return Text(
                  'Hello',
                  style: Theme.of(context).textTheme.bodyLarge,
                );
              },
            ),
          ),
        );

        expect(tokens, isNotNull);
        expect(tokens.colors.primary, const Color(0xFF0E9FA6));
        expect(find.text('Hello'), findsOneWidget);
      },
    );

    testWidgets('Material Card inherits cardTheme configuration from tokens', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          const Card(
            child: SizedBox(
              width: 100,
              height: 100,
              child: Text('CardContent'),
            ),
          ),
        ),
      );

      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);

      final Card card = tester.widget<Card>(cardFinder);
      expect(card.color, isNull); // Falls back to cardTheme.color
      expect(card.elevation, isNull); // Falls back to cardTheme.elevation

      final BuildContext context = tester.element(cardFinder);
      final theme = Theme.of(context);
      expect(theme.cardTheme.color, const Color(0xFFFFFFFF));
      expect(theme.cardTheme.elevation, 0);

      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
      expect(shape.side.color, const Color(0xFFE4E8EE));
    });

    testWidgets(
      'Material InputDecoration inherits border radius and colors from tokens',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            const TextField(
              decoration: InputDecoration(hintText: 'Search patient...'),
            ),
          ),
        );

        final BuildContext context = tester.element(find.byType(TextField));
        final theme = Theme.of(context);
        final inputTheme = theme.inputDecorationTheme;

        expect(inputTheme.filled, isTrue);
        expect(inputTheme.fillColor, const Color(0xFFFFFFFF));

        final border = inputTheme.border as OutlineInputBorder;
        expect(border.borderRadius, BorderRadius.circular(12));
        expect(border.borderSide.color, const Color(0xFFE4E8EE));

        final focusedBorder = inputTheme.focusedBorder as OutlineInputBorder;
        expect(focusedBorder.borderRadius, BorderRadius.circular(12));
        expect(focusedBorder.borderSide.color, const Color(0xFF0E9FA6));
      },
    );

    testWidgets('Material Divider inherits dividerTheme color from tokens', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp(const Divider()));

      final BuildContext context = tester.element(find.byType(Divider));
      final theme = Theme.of(context);
      expect(theme.dividerTheme.color, const Color(0xFFE4E8EE));
      expect(theme.dividerTheme.thickness, 1);
    });

    testWidgets(
      'Material BottomSheetTheme inherits rounded top corners from tokens',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) =>
                          const SizedBox(height: 200, child: Text('Sheet')),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        );

        final BuildContext context = tester.element(
          find.byType(ElevatedButton),
        );
        final theme = Theme.of(context);
        final sheetShape =
            theme.bottomSheetTheme.shape as RoundedRectangleBorder;
        expect(
          sheetShape.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(24)),
        );
      },
    );
  });

  group('Status indicators communicate color, icon, and readable text', () {
    testWidgets('Admitted status renders color + log-in icon + readable text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _testApp(const WlStatusChip(PatientStatus.admitted)),
      );

      // 1. Text is readable
      expect(find.text('Admitted'), findsOneWidget);

      // 2. Icon is present and matches Lucide log-in
      final iconFinder = find.byType(Icon);
      expect(iconFinder, findsOneWidget);
      final Icon icon = tester.widget<Icon>(iconFinder);
      expect(icon.icon, LucideIcons.logIn);
      expect(icon.color, const Color(0xFF1F55C2)); // Foreground

      // 3. Background color is applied
      final containerFinder = find.byType(AnimatedContainer);
      expect(containerFinder, findsOneWidget);
      final AnimatedContainer container = tester.widget<AnimatedContainer>(
        containerFinder,
      );
      final box = container.decoration as BoxDecoration;
      expect(box.color, const Color(0xFFEAF1FD)); // Background

      // 4. Accessible semantics
      expect(find.bySemanticsLabel('Status: Admitted'), findsOneWidget);
      handle.dispose();
    });

    testWidgets(
      'In Treatment status renders color + activity icon + readable text',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _testApp(const WlStatusChip(PatientStatus.inTreatment)),
        );

        expect(find.text('In Treatment'), findsOneWidget);

        final Icon icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, LucideIcons.activity);
        expect(icon.color, const Color(0xFF6236C0));

        final AnimatedContainer container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final box = container.decoration as BoxDecoration;
        expect(box.color, const Color(0xFFF1ECFC));

        expect(find.bySemanticsLabel('Status: In Treatment'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets(
      'Ready for Discharge status renders color + circle-check icon + readable text',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _testApp(const WlStatusChip(PatientStatus.readyForDischarge)),
        );

        expect(find.text('Ready for Discharge'), findsOneWidget);

        final Icon icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, LucideIcons.circleCheck);
        expect(icon.color, const Color(0xFF0D7A43));

        final AnimatedContainer container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final box = container.decoration as BoxDecoration;
        expect(box.color, const Color(0xFFE6F6EE));

        expect(
          find.bySemanticsLabel('Status: Ready for Discharge'),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'Ready for Discharge status in short form renders Ready + full semantics',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _testApp(
            const WlStatusChip(
              PatientStatus.readyForDischarge,
              short: true,
              size: WlChipSize.sm,
            ),
          ),
        );

        // Short visible text for dense lists
        expect(find.text('Ready'), findsOneWidget);
        expect(find.text('Ready for Discharge'), findsNothing);

        // Semantics still communicates full label for accessibility
        expect(
          find.bySemanticsLabel('Status: Ready for Discharge'),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'Discharged status renders color + log-out icon + readable text',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _testApp(const WlStatusChip(PatientStatus.discharged)),
        );

        expect(find.text('Discharged'), findsOneWidget);

        final Icon icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, LucideIcons.logOut);
        expect(icon.color, const Color(0xFF4F5967));

        final AnimatedContainer container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final box = container.decoration as BoxDecoration;
        expect(box.color, const Color(0xFFF0F2F5));

        expect(find.bySemanticsLabel('Status: Discharged'), findsOneWidget);
        handle.dispose();
      },
    );
  });

  group('WlMotion.reduced', () {
    Future<bool> pumpAndRead(
      WidgetTester tester, {
      required bool system,
      required bool app,
    }) async {
      late bool result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: system),
          child: WlMotionScope(
            reduceMotion: app,
            child: Builder(
              builder: (context) {
                result = WlMotion.reduced(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return result;
    }

    testWidgets('follows the system setting or the in-app switch', (
      tester,
    ) async {
      expect(await pumpAndRead(tester, system: false, app: false), isFalse);
      expect(await pumpAndRead(tester, system: true, app: false), isTrue);
      expect(await pumpAndRead(tester, system: false, app: true), isTrue);
    });
  });
}

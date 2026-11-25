import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/theme.dart';
import 'package:wardline/core/theme/wl_tokens.dart';

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: buildTheme(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('ThemeData and WlTokens registration', () {
    test(
      'WlTokens is correctly registered as a ThemeExtension on ThemeData',
      () {
        final ThemeData theme = buildTheme();
        final tokens = theme.extension<WlTokens>();
        expect(tokens, isNotNull);
        expect(theme.scaffoldBackgroundColor, tokens!.colors.page);
        expect(theme.colorScheme.primary, tokens.colors.primaryInk);
        expect(theme.colorScheme.surface, tokens.colors.surface);
        expect(theme.dividerColor, tokens.colors.border);
      },
    );

    testWidgets('The extension can be retrieved through Theme.of(context)', (
      tester,
    ) async {
      late WlTokens tokens;
      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (context) {
              tokens = WlTokens.of(context);
              return Text(
                'Wardline',
                style: Theme.of(context).textTheme.bodyLarge,
              );
            },
          ),
        ),
      );

      expect(tokens, isNotNull);
      expect(tokens.colors.primary, const Color(0xFF0E9FA6));
      expect(find.text('Wardline'), findsOneWidget);
    });
  });

  group('Token logic used across the app', () {
    test('every status has a label; the short form keeps the full one', () {
      const WlColors c = WlColors();
      for (final s in PatientStatus.values) {
        expect(c.status(s).label, isNotEmpty);
      }
      expect(c.status(PatientStatus.readyForDischarge).shortLabel, 'Ready');
      expect(
        c.status(PatientStatus.readyForDischarge).label,
        'Ready for Discharge',
      );
    });

    test('occupancy thresholds: <60 low, 60–85 medium, >85 high', () {
      const WlColors c = WlColors();
      expect(c.occupancy(59).level, OccupancyLevel.low);
      expect(c.occupancy(60).level, OccupancyLevel.medium);
      expect(c.occupancy(85).level, OccupancyLevel.medium);
      expect(c.occupancy(86).level, OccupancyLevel.high);
      expect(c.occupancy(100).word, 'High');
    });
  });

  group('Material component theme fallbacks', () {
    testWidgets('Material Card receives the intended theme styling', (
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

      final BuildContext context = tester.element(cardFinder);
      final theme = Theme.of(context);
      final tokens = WlTokens.of(context);

      expect(theme.cardTheme.color, tokens.colors.surface);
      expect(theme.cardTheme.elevation, 0);

      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, tokens.radius.cardBr);
      expect(shape.side.color, tokens.colors.border);
    });

    testWidgets('TextField receives the intended input decoration theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          const TextField(
            decoration: InputDecoration(hintText: 'Search patient...'),
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(TextField));
      final theme = Theme.of(context);
      final tokens = WlTokens.of(context);
      final inputTheme = theme.inputDecorationTheme;

      expect(inputTheme.filled, isTrue);
      expect(inputTheme.fillColor, tokens.colors.surface);

      final border = inputTheme.border as OutlineInputBorder;
      expect(border.borderRadius, tokens.radius.inputBr);
      expect(border.borderSide.color, tokens.colors.border);

      final focusedBorder = inputTheme.focusedBorder as OutlineInputBorder;
      expect(focusedBorder.borderRadius, tokens.radius.inputBr);
      expect(focusedBorder.borderSide.color, tokens.colors.primary);
      expect(focusedBorder.borderSide.width, 1.0);

      expect(inputTheme.hintStyle?.color, tokens.colors.textSecondary);
    });

    testWidgets('Divider receives the intended theme styling', (tester) async {
      await tester.pumpWidget(_testApp(const Divider()));

      final BuildContext context = tester.element(find.byType(Divider));
      final theme = Theme.of(context);
      final tokens = WlTokens.of(context);

      expect(theme.dividerTheme.color, tokens.colors.border);
      expect(theme.dividerTheme.thickness, 1);
    });

    testWidgets('Bottom sheets receive the intended fallback theme styling', (
      tester,
    ) async {
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

      final BuildContext context = tester.element(find.byType(ElevatedButton));
      final theme = Theme.of(context);
      final tokens = WlTokens.of(context);
      final sheetShape = theme.bottomSheetTheme.shape as RoundedRectangleBorder;

      expect(sheetShape.borderRadius, tokens.radius.sheetBr);
      expect(theme.bottomSheetTheme.backgroundColor, tokens.colors.surface);
    });
  });

  group('WlMotion.reduced behavioral logic', () {
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

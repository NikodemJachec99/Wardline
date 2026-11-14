import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/theme.dart';
import 'package:wardline/core/theme/wl_tokens.dart';

void main() {
  group('WlTokens', () {
    test('is registered on the app theme', () {
      final ThemeData theme = buildTheme();
      expect(theme.extension<WlTokens>(), isNotNull);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFBFC));
      expect(theme.colorScheme.primary, const Color(0xFF0A7F85));
    });

    test('status styles match the design system', () {
      const WlColors c = WlColors();
      expect(c.status(PatientStatus.admitted).base, const Color(0xFF2F6FEB));
      expect(c.status(PatientStatus.inTreatment).base, const Color(0xFF7C4DDB));
      expect(
        c.status(PatientStatus.readyForDischarge).base,
        const Color(0xFF14A35B),
      );
      expect(c.status(PatientStatus.discharged).base, const Color(0xFF8A94A3));
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

    test('motion tokens', () {
      const WlMotionTokens m = WlMotionTokens();
      expect(m.fast, const Duration(milliseconds: 120));
      expect(m.base, const Duration(milliseconds: 220));
      expect(m.slow, const Duration(milliseconds: 380));
    });
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

// Wardline design tokens as a ThemeExtension.
// Source: design/handoff/tokens.json. Names match the design canvas 1:1.
// Move to app/lib/core/theme/wl_tokens.dart and register in buildTheme():
//
//   ThemeData(
//     useMaterial3: true,
//     fontFamily: 'Inter',
//     scaffoldBackgroundColor: WlTokens.light.colors.page,
//     extensions: const <ThemeExtension<dynamic>>[WlTokens.light],
//   )
//
// Read it with `WlTokens.of(context)`.

import 'package:flutter/material.dart';

enum PatientStatus { admitted, inTreatment, readyForDischarge, discharged }

enum UserRole { nurse, doctor, admin }

enum OccupancyLevel { low, medium, high }

@immutable
class WlStatusStyle {
  const WlStatusStyle({
    required this.base,
    required this.fg,
    required this.bg,
    required this.label,
    required this.shortLabel,
    required this.lucideIcon,
  });

  /// Bars, dots, chart marks.
  final Color base;

  /// Text and icon on [bg].
  final Color fg;
  final Color bg;
  final String label;
  final String shortLabel;

  /// Lucide icon name; map to IconData in the widget layer.
  final String lucideIcon;
}

@immutable
class WlOccupancyStyle {
  const WlOccupancyStyle(this.level, this.fill, this.tint, this.word);
  final OccupancyLevel level;
  final Color fill;
  final Color tint;

  /// Spoken/visible word so colour is never the only signal.
  final String word;
}

@immutable
class WlRoleStyle {
  const WlRoleStyle(this.ring, this.bg, this.fg, this.label);
  final Color ring;
  final Color bg;
  final Color fg;
  final String label;
}

@immutable
class WlColors {
  const WlColors();

  final Color primary = const Color(0xFF0E9FA6);
  final Color primaryPressed = const Color(0xFF0B858B);
  final Color primarySoft = const Color(0xFFE4F5F6);
  final Color primaryInk = const Color(0xFF0A7F85);
  final Color primaryInkPressed = const Color(0xFF086A6F);

  final Color page = const Color(0xFFFAFBFC);
  final Color surface = const Color(0xFFFFFFFF);
  final Color subtle = const Color(0xFFF3F5F8);
  final Color border = const Color(0xFFE4E8EE);
  final Color borderStrong = const Color(0xFFCBD2DB);

  final Color text = const Color(0xFF0F1720);
  final Color textSecondary = const Color(0xFF5B6675);
  final Color textDisabled = const Color(0xFF9AA3AF);
  final Color onPrimary = const Color(0xFFFFFFFF);

  final Color danger = const Color(0xFFC9302C);
  final Color dangerPressed = const Color(0xFFA82622);
  final Color dangerBg = const Color(0xFFFDECEC);
  final Color warning = const Color(0xFFD97F0E);
  final Color warningFg = const Color(0xFF8A5207);
  final Color warningBg = const Color(0xFFFFF6E8);
  final Color warningBorder = const Color(0xFFF6D9A8);

  /// #0F1720 at 32%.
  final Color scrim = const Color(0x520F1720);

  /// White 72% fill + white 60% hairline. No BackdropFilter.
  final Color glassFill = const Color(0xB8FFFFFF);
  final Color glassBorder = const Color(0x99FFFFFF);

  LinearGradient get dashboardHeader => const LinearGradient(
        // 340° in CSS = dark end at the top-left, under the greeting text.
        begin: Alignment(-0.34, -0.94),
        end: Alignment(0.34, 0.94),
        colors: <Color>[Color(0xFF0A7F85), Color(0xFF13A8AE)],
      );

  WlStatusStyle status(PatientStatus s) {
    switch (s) {
      case PatientStatus.admitted:
        return const WlStatusStyle(
          base: Color(0xFF2F6FEB),
          fg: Color(0xFF1F55C2),
          bg: Color(0xFFEAF1FD),
          label: 'Admitted',
          shortLabel: 'Admitted',
          lucideIcon: 'log-in',
        );
      case PatientStatus.inTreatment:
        return const WlStatusStyle(
          base: Color(0xFF7C4DDB),
          fg: Color(0xFF6236C0),
          bg: Color(0xFFF1ECFC),
          label: 'In Treatment',
          shortLabel: 'In Treatment',
          lucideIcon: 'activity',
        );
      case PatientStatus.readyForDischarge:
        return const WlStatusStyle(
          base: Color(0xFF14A35B),
          fg: Color(0xFF0D7A43),
          bg: Color(0xFFE6F6EE),
          label: 'Ready for Discharge',
          shortLabel: 'Ready',
          lucideIcon: 'circle-check',
        );
      case PatientStatus.discharged:
        return const WlStatusStyle(
          base: Color(0xFF8A94A3),
          fg: Color(0xFF4F5967),
          bg: Color(0xFFF0F2F5),
          label: 'Discharged',
          shortLabel: 'Discharged',
          lucideIcon: 'log-out',
        );
    }
  }

  /// <60 low · 60–85 medium · >85 high.
  WlOccupancyStyle occupancy(int percent) {
    if (percent > 85) {
      return const WlOccupancyStyle(
          OccupancyLevel.high, Color(0xFFE5484D), Color(0xFFFCE6E7), 'High');
    }
    if (percent >= 60) {
      return const WlOccupancyStyle(
          OccupancyLevel.medium, Color(0xFFF29A2E), Color(0xFFFDF0DD), 'Medium');
    }
    return const WlOccupancyStyle(
        OccupancyLevel.low, Color(0xFF22B573), Color(0xFFE3F6EC), 'Low');
  }

  WlRoleStyle role(UserRole r) {
    switch (r) {
      case UserRole.nurse:
        return const WlRoleStyle(
            Color(0xFF0E9FA6), Color(0xFFE4F5F6), Color(0xFF0A7F85), 'Nurse');
      case UserRole.doctor:
        return const WlRoleStyle(
            Color(0xFF7C4DDB), Color(0xFFF1ECFC), Color(0xFF6236C0), 'Doctor');
      case UserRole.admin:
        return const WlRoleStyle(
            Color(0xFF4F5967), Color(0xFFF0F2F5), Color(0xFF4F5967), 'Admin');
    }
  }
}

@immutable
class WlSpace {
  const WlSpace();
  final double xxs = 4;
  final double xs = 8;
  final double sm = 12;
  final double md = 16;
  final double lg = 24;
  final double xl = 32;
  final double xxl = 48;
  final double gutter = 16;
  final double touchMin = 48;
  final double action = 56;
  final double input = 48;
  final double navBar = 64;
  final double scanButton = 64;
}

@immutable
class WlRadius {
  const WlRadius();
  final double chip = 8;
  final double input = 12;
  final double card = 16;
  final double sheet = 24;
  final double full = 999;

  BorderRadius get chipBr => BorderRadius.circular(chip);
  BorderRadius get inputBr => BorderRadius.circular(input);
  BorderRadius get cardBr => BorderRadius.circular(card);
  BorderRadius get sheetBr =>
      const BorderRadius.vertical(top: Radius.circular(24));
}

@immutable
class WlElevation {
  const WlElevation();
  List<BoxShadow> get e1 => const <BoxShadow>[
        BoxShadow(color: Color(0x0A0F1720), offset: Offset(0, 1), blurRadius: 2),
        BoxShadow(color: Color(0x0A0F1720), offset: Offset(0, 2), blurRadius: 8),
      ];
  List<BoxShadow> get e2 => const <BoxShadow>[
        BoxShadow(color: Color(0x140F1720), offset: Offset(0, 6), blurRadius: 20),
      ];
  List<BoxShadow> get e3 => const <BoxShadow>[
        BoxShadow(color: Color(0x1F0F1720), offset: Offset(0, -8), blurRadius: 32),
      ];
}

@immutable
class WlMotionTokens {
  const WlMotionTokens();
  final Duration fast = const Duration(milliseconds: 120);
  final Duration base = const Duration(milliseconds: 220);
  final Duration slow = const Duration(milliseconds: 380);
  final Curve out = Curves.easeOutCubic;
  final Curve inOut = Curves.easeInOutCubic;
  SpringDescription get sheetSpring =>
      const SpringDescription(mass: 1, stiffness: 420, damping: 38);
}

@immutable
class WlType {
  const WlType();
  static const String _f = 'Inter';
  static const List<FontFeature> _tnum = <FontFeature>[
    FontFeature.tabularFigures()
  ];

  TextStyle get display => const TextStyle(
      fontFamily: _f, fontSize: 34, height: 40 / 34, fontWeight: FontWeight.w700, letterSpacing: -0.68);
  TextStyle get title1 => const TextStyle(
      fontFamily: _f, fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w700, letterSpacing: -0.56);
  TextStyle get title2 => const TextStyle(
      fontFamily: _f, fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, letterSpacing: -0.22);
  TextStyle get title3 => const TextStyle(
      fontFamily: _f, fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600);
  TextStyle get body => const TextStyle(
      fontFamily: _f, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400);
  TextStyle get label => const TextStyle(
      fontFamily: _f, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600);
  TextStyle get callout => const TextStyle(
      fontFamily: _f, fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w500);
  TextStyle get subhead => const TextStyle(
      fontFamily: _f, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  TextStyle get caption => const TextStyle(
      fontFamily: _f, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500);

  /// Render with `.toUpperCase()` on the string.
  TextStyle get overline => const TextStyle(
      fontFamily: _f, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w600, letterSpacing: 0.66);
  TextStyle get kpi => const TextStyle(
      fontFamily: _f, fontSize: 32, height: 36 / 32, fontWeight: FontWeight.w600, letterSpacing: -0.64, fontFeatures: _tnum);
  TextStyle get id => const TextStyle(
      fontFamily: _f,
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.26,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures(), FontFeature.slashedZero()]);

  /// Any time, count or percentage that can change live.
  TextStyle tabular(TextStyle s) => s.copyWith(fontFeatures: _tnum);
}

@immutable
class WlTokens extends ThemeExtension<WlTokens> {
  const WlTokens({
    this.colors = const WlColors(),
    this.space = const WlSpace(),
    this.radius = const WlRadius(),
    this.elevation = const WlElevation(),
    this.motion = const WlMotionTokens(),
    this.type = const WlType(),
  });

  static const WlTokens light = WlTokens();

  final WlColors colors;
  final WlSpace space;
  final WlRadius radius;
  final WlElevation elevation;
  final WlMotionTokens motion;
  final WlType type;

  static WlTokens of(BuildContext context) =>
      Theme.of(context).extension<WlTokens>() ?? light;

  @override
  WlTokens copyWith({
    WlColors? colors,
    WlSpace? space,
    WlRadius? radius,
    WlElevation? elevation,
    WlMotionTokens? motion,
    WlType? type,
  }) {
    return WlTokens(
      colors: colors ?? this.colors,
      space: space ?? this.space,
      radius: radius ?? this.radius,
      elevation: elevation ?? this.elevation,
      motion: motion ?? this.motion,
      type: type ?? this.type,
    );
  }

  /// Single light theme: no interpolation needed.
  @override
  WlTokens lerp(ThemeExtension<WlTokens>? other, double t) =>
      (other is WlTokens && t >= 0.5) ? other : this;
}

/// Reduced motion = system setting OR the in-app "Reduce motion" switch.
/// Provide the app switch with [WlMotionScope] near the root.
class WlMotionScope extends InheritedWidget {
  const WlMotionScope({
    required this.reduceMotion,
    required super.child,
    super.key,
  });

  final bool reduceMotion;

  @override
  bool updateShouldNotify(WlMotionScope oldWidget) =>
      oldWidget.reduceMotion != reduceMotion;
}

abstract final class WlMotion {
  static bool reduced(BuildContext context) {
    final bool system = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool app = context
            .dependOnInheritedWidgetOfExactType<WlMotionScope>()
            ?.reduceMotion ??
        false;
    return system || app;
  }

  /// Duration helper: returns [Duration.zero] or [fallback] when reduced.
  static Duration of(BuildContext context, Duration normal,
          {Duration fallback = Duration.zero}) =>
      reduced(context) ? fallback : normal;
}

// Wardline design tokens as a ThemeExtension.
// Source: design/handoff/tokens.json. Names match the design canvas 1:1.
// Read with `WlTokens.of(context)`. Never hard-code colours, sizes or
// durations in widgets: take them from here.

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

  /// Dense lists only. Semantics always use [label].
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

  /// Visible/spoken word so colour is never the only signal.
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

  /// Brand fills only: Scan button, app icon, focus ring, charts.
  /// 3.2:1 on white, never use for text.
  Color get primary => const Color(0xFF0E9FA6);
  Color get primaryPressed => const Color(0xFF0B858B);
  Color get primarySoft => const Color(0xFFE4F5F6);

  /// Button fills with text, teal text, links. 4.8:1 on white.
  Color get primaryInk => const Color(0xFF0A7F85);
  Color get primaryInkPressed => const Color(0xFF086A6F);

  Color get page => const Color(0xFFFAFBFC);
  Color get surface => const Color(0xFFFFFFFF);
  Color get subtle => const Color(0xFFF3F5F8);

  /// PLAN.md §7.1 direct token aliases
  Color get bg => page;
  Color get surface2 => subtle;
  Color get border => const Color(0xFFE4E8EE);
  Color get borderStrong => const Color(0xFFCBD2DB);

  Color get text => const Color(0xFF0F1720);
  Color get textSecondary => const Color(0xFF5B6675);
  Color get textMuted => textSecondary;
  Color get textDisabled => const Color(0xFF9AA3AF);
  Color get onPrimary => const Color(0xFFFFFFFF);

  /// Direct status colors from PLAN.md §7.1
  Color get statusAdmitted => const Color(0xFF2F6FEB);
  Color get statusInTreatment => const Color(0xFF7C4DDB);
  Color get statusReadyForDischarge => const Color(0xFF14A35B);
  Color get statusDischarged => const Color(0xFF8A94A3);

  /// Direct heat colors from PLAN.md §7.1
  Color get heatLow => const Color(0xFF22B573);
  Color get heatMedium => const Color(0xFFF29A2E);
  Color get heatHigh => const Color(0xFFE5484D);

  Color get danger => const Color(0xFFC9302C);
  Color get dangerPressed => const Color(0xFFA82622);
  Color get dangerBg => const Color(0xFFFDECEC);
  Color get warning => const Color(0xFFD97F0E);
  Color get warningFg => const Color(0xFF8A5207);
  Color get warningBg => const Color(0xFFFFF6E8);
  Color get warningBorder => const Color(0xFFF6D9A8);

  /// #0F1720 at 32%.
  Color get scrim => const Color(0x520F1720);

  /// White 72% fill + white 60% hairline. No BackdropFilter.
  Color get glassFill => const Color(0xB8FFFFFF);
  Color get glassBorder => const Color(0x99FFFFFF);

  /// Dashboard header only. Dark end top-left, under the greeting text.
  LinearGradient get dashboardHeader => const LinearGradient(
    begin: Alignment(-0.34, -0.94),
    end: Alignment(0.34, 0.94),
    colors: <Color>[Color(0xFF0A7F85), Color(0xFF13A8AE)],
  );

  WlStatusStyle status(PatientStatus status) {
    switch (status) {
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

  /// Below 60 low, 60–85 medium, above 85 high.
  WlOccupancyStyle occupancy(int percent) {
    if (percent > 85) {
      return const WlOccupancyStyle(
        OccupancyLevel.high,
        Color(0xFFE5484D),
        Color(0xFFFCE6E7),
        'High',
      );
    }
    if (percent >= 60) {
      return const WlOccupancyStyle(
        OccupancyLevel.medium,
        Color(0xFFF29A2E),
        Color(0xFFFDF0DD),
        'Medium',
      );
    }
    return const WlOccupancyStyle(
      OccupancyLevel.low,
      Color(0xFF22B573),
      Color(0xFFE3F6EC),
      'Low',
    );
  }

  WlRoleStyle role(UserRole role) {
    switch (role) {
      case UserRole.nurse:
        return const WlRoleStyle(
          Color(0xFF0E9FA6),
          Color(0xFFE4F5F6),
          Color(0xFF0A7F85),
          'Nurse',
        );
      case UserRole.doctor:
        return const WlRoleStyle(
          Color(0xFF7C4DDB),
          Color(0xFFF1ECFC),
          Color(0xFF6236C0),
          'Doctor',
        );
      case UserRole.admin:
        return const WlRoleStyle(
          Color(0xFF4F5967),
          Color(0xFFF0F2F5),
          Color(0xFF4F5967),
          'Admin',
        );
    }
  }
}

@immutable
class WlSpace {
  const WlSpace();

  double get xxs => 4;
  double get xs => 8;
  double get sm => 12;
  double get md => 16;
  double get lg => 24;
  double get xl => 32;
  double get xxl => 48;
  double get gutter => 16;
  double get touchMin => 48;
  double get action => 56;
  double get input => 48;
  double get navBar => 64;
  double get scanButton => 64;
}

@immutable
class WlRadius {
  const WlRadius();

  double get chip => 8;
  double get input => 12;
  double get card => 16;
  double get sheet => 24;
  double get full => 999;

  BorderRadius get chipBr => BorderRadius.circular(chip);
  BorderRadius get inputBr => BorderRadius.circular(input);
  BorderRadius get cardBr => BorderRadius.circular(card);
  BorderRadius get sheetBr =>
      BorderRadius.vertical(top: Radius.circular(sheet));
}

@immutable
class WlElevation {
  const WlElevation();

  /// Sticky search after scroll.
  List<BoxShadow> get e1 => const <BoxShadow>[
    BoxShadow(color: Color(0x0A0F1720), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0A0F1720), offset: Offset(0, 2), blurRadius: 8),
  ];

  /// Scan button, toast, map panel.
  List<BoxShadow> get e2 => const <BoxShadow>[
    BoxShadow(color: Color(0x140F1720), offset: Offset(0, 6), blurRadius: 20),
  ];

  /// Bottom sheets.
  List<BoxShadow> get e3 => const <BoxShadow>[
    BoxShadow(color: Color(0x1F0F1720), offset: Offset(0, -8), blurRadius: 32),
  ];
}

@immutable
class WlMotionTokens {
  const WlMotionTokens();

  Duration get fast => const Duration(milliseconds: 120);
  Duration get base => const Duration(milliseconds: 220);
  Duration get slow => const Duration(milliseconds: 380);
  Curve get out => Curves.easeOutCubic;
  Curve get inOut => Curves.easeInOutCubic;

  /// Map (motion.md): realtime dot travels A→B once per event.
  Duration get mapDotTravel => const Duration(milliseconds: 2600);

  /// Map: arrival ring on B (also the reduced-motion highlight).
  Duration get mapArrivalRing => const Duration(milliseconds: 2000);

  /// Map: route polyline draw; stops pop in [routeStopStagger] apart.
  Duration get routeDraw => const Duration(milliseconds: 900);
  Duration get routeStopStagger => const Duration(milliseconds: 80);

  /// Damping ratio ≈ 0.93: settles without a visible bounce.
  SpringDescription get sheetSpring =>
      const SpringDescription(mass: 1, stiffness: 420, damping: 38);
}

@immutable
class WlType {
  const WlType();

  static const String family = 'Inter';
  static const List<FontFeature> _tnum = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  TextStyle get display => const TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 40 / 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.68,
  );
  TextStyle get title1 => const TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.56,
  );
  TextStyle get title2 => const TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.22,
  );
  TextStyle get title3 => const TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );
  TextStyle get body => const TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );
  TextStyle get label => const TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );
  TextStyle get callout => const TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
  );
  TextStyle get subhead => const TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );
  TextStyle get caption => const TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// Render the string with `.toUpperCase()`.
  TextStyle get overline => const TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.66,
  );
  TextStyle get kpi => const TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 36 / 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.64,
    fontFeatures: _tnum,
  );
  TextStyle get id => const TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.26,
    fontFeatures: <FontFeature>[
      FontFeature.tabularFigures(),
      FontFeature.slashedZero(),
    ],
  );

  /// For any time, count or percentage that can change live.
  TextStyle tabular(TextStyle style) => style.copyWith(fontFeatures: _tnum);
}

@immutable
class WlTokens extends ThemeExtension<WlTokens> {
  const WlTokens({
    this.colors = const WlColors(),
    this.space = const WlSpace(),
    this.radius = const WlRadius(),
    this.elevation = const WlElevation(),
    this.motion = const WlMotionTokens(),
    this.typography = const WlType(),
  });

  static const WlTokens light = WlTokens();

  final WlColors colors;
  final WlSpace space;
  final WlRadius radius;
  final WlElevation elevation;
  final WlMotionTokens motion;
  final WlType typography;

  static WlTokens of(BuildContext context) =>
      Theme.of(context).extension<WlTokens>() ?? light;

  @override
  WlTokens copyWith({
    WlColors? colors,
    WlSpace? space,
    WlRadius? radius,
    WlElevation? elevation,
    WlMotionTokens? motion,
    WlType? typography,
  }) {
    return WlTokens(
      colors: colors ?? this.colors,
      space: space ?? this.space,
      radius: radius ?? this.radius,
      elevation: elevation ?? this.elevation,
      motion: motion ?? this.motion,
      typography: typography ?? this.typography,
    );
  }

  /// Single light theme, so there is nothing to interpolate.
  @override
  WlTokens lerp(ThemeExtension<WlTokens>? other, double t) =>
      (other is WlTokens && t >= 0.5) ? other : this;
}

/// Provides the in-app "Reduce motion" setting. Put it near the app root.
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

/// Reduced motion = system setting OR the in-app switch.
abstract final class WlMotion {
  static bool reduced(BuildContext context) {
    final bool system = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool app =
        context
            .dependOnInheritedWidgetOfExactType<WlMotionScope>()
            ?.reduceMotion ??
        false;
    return system || app;
  }

  /// [normal] or [fallback] (zero by default) when motion is reduced.
  static Duration duration(
    BuildContext context,
    Duration normal, {
    Duration fallback = Duration.zero,
  }) => reduced(context) ? fallback : normal;
}

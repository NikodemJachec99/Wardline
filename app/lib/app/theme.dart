import 'package:flutter/material.dart';

import '../core/theme/wl_tokens.dart';

/// App theme built from the Wardline design tokens
/// (PLAN.md §7.1, design/handoff/tokens.json, `WlTokens`).
///
/// Note on Material component themes:
/// Custom Wardline components (`Wl*`, `WlLargeTitle`, `showWlBottomSheet`)
/// remain the primary design implementation throughout the app.
/// The Material component themes configured below (`cardTheme`, `inputDecorationTheme`,
/// `bottomSheetTheme`, `dividerTheme`, `chipTheme`, `appBarTheme`) serve as consistent
/// fallbacks for standard Flutter Material widgets, ensuring token alignment.
/// Note that `bottomSheetTheme` provides fallback defaults and does not override the
/// custom background and scrim implementation in `showWlBottomSheet`.
ThemeData buildTheme() {
  const WlTokens tokens = WlTokens.light;
  final WlColors c = tokens.colors;
  final WlSpace sp = tokens.space;
  final WlRadius rad = tokens.radius;

  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: c.primary)
      .copyWith(
        primary: c.primaryInk,
        onPrimary: c.onPrimary,
        primaryContainer: c.primarySoft,
        onPrimaryContainer: c.primaryInk,
        secondary: c.primary,
        surface: c.surface,
        onSurface: c.text,
        onSurfaceVariant: c.textSecondary,
        surfaceContainerHighest: c.subtle,
        outline: c.borderStrong,
        outlineVariant: c.border,
        error: c.danger,
        onError: c.onPrimary,
        scrim: c.scrim,
      );

  final TextTheme text = TextTheme(
    displaySmall: tokens.typography.display,
    headlineMedium: tokens.typography.title1,
    headlineSmall: tokens.typography.title2,
    titleLarge: tokens.typography.title2,
    titleMedium: tokens.typography.title3,
    titleSmall: tokens.typography.callout,
    bodyLarge: tokens.typography.body,
    bodyMedium: tokens.typography.subhead,
    bodySmall: tokens.typography.caption,
    labelLarge: tokens.typography.label,
    labelMedium: tokens.typography.caption,
    labelSmall: tokens.typography.overline,
  ).apply(bodyColor: c.text, displayColor: c.text);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: WlType.family,
    textTheme: text,
    scaffoldBackgroundColor: c.page,
    dividerColor: c.border,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: rad.cardBr,
        side: BorderSide(color: c.border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: EdgeInsets.symmetric(horizontal: sp.md, vertical: sp.sm),
      border: OutlineInputBorder(
        borderRadius: rad.inputBr,
        borderSide: BorderSide(color: c.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: rad.inputBr,
        borderSide: BorderSide(color: c.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: rad.inputBr,
        borderSide: BorderSide(color: c.primary, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: rad.inputBr,
        borderSide: BorderSide(color: c.danger, width: 1),
      ),
      hintStyle: tokens.typography.subhead.copyWith(color: c.textSecondary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: c.surface.withValues(alpha: 0),
      shape: RoundedRectangleBorder(borderRadius: rad.sheetBr),
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: c.subtle,
      shape: RoundedRectangleBorder(borderRadius: rad.chipBr),
      side: BorderSide.none,
      labelStyle: tokens.typography.subhead,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.page,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: tokens.typography.title3.copyWith(color: c.text),
      iconTheme: IconThemeData(color: c.text),
    ),
    extensions: const <ThemeExtension<dynamic>>[WlTokens.light],
  );
}

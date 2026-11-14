import 'package:flutter/material.dart';

import '../core/theme/wl_tokens.dart';

/// App theme built from the Wardline design tokens
/// (design/handoff/tokens.json, `WlTokens`).
ThemeData buildTheme() {
  const WlTokens tokens = WlTokens.light;
  final WlColors c = tokens.colors;

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
    extensions: const <ThemeExtension<dynamic>>[WlTokens.light],
  );
}

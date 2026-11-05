import 'package:flutter/material.dart';

/// Brand colour from docs/PLAN.md §7.1. Full design tokens land with the
/// design-system issue.
const Color kPrimary = Color(0xFF0E9FA6);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
    scaffoldBackgroundColor: const Color(0xFFFAFBFC),
  );
}

import 'package:flutter/material.dart';

class DokployTheme {
  // Dokploy's dark theme is deliberately neutral: near-black background,
  // graphite surfaces and an off-white primary. Color is reserved for state.
  static const primary = Color(0xFFEBEBED);
  static const onPrimary = Color(0xFF202024);
  static const bg = Color(0xFF0A0A0A);
  static const panel = Color(0xD91B1B1E);
  static const elevated = Color(0xFF28282D);
  static const border = Color(0x1AFFFFFF);
  static const muted = Color(0xFFA1A1AA);
  static const info = Color(0xFF60A5FA);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: panel,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: elevated,
      onSecondary: primary,
      outline: border,
      surfaceContainer: panel,
      surfaceContainerHigh: elevated,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: border),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: panel,
        indicatorColor: elevated,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: elevated,
        side: BorderSide(color: border),
      ),
      dividerColor: border,
    );
  }

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF18181B)),
      );
}

import 'package:flutter/cupertino.dart';
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

  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: _DployGoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: _DployGoPageTransitionsBuilder(),
      TargetPlatform.linux: _DployGoPageTransitionsBuilder(),
      TargetPlatform.windows: _DployGoPageTransitionsBuilder(),
    },
  );

  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color panelOf(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainer;
  static Color elevatedOf(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;
  static Color borderOf(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;
  static Color foregroundOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  static Color mutedOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

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
      outlineVariant: border,
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
      pageTransitionsTheme: _pageTransitions,
    );
  }

  static ThemeData get light {
    const lightBg = Color(0xFFF4F4F5);
    const lightPanel = Color(0xEFFFFFFF);
    const lightElevated = Color(0xFFE4E4E7);
    const lightBorder = Color(0xFFD4D4D8);
    const lightPrimary = Color(0xFF18181B);
    const lightMuted = Color(0xFF52525B);
    const lightOnPrimary = Color(0xFFFAFAFA);
    const scheme = ColorScheme.light(
      primary: lightPrimary,
      onPrimary: lightOnPrimary,
      secondary: lightElevated,
      onSecondary: lightPrimary,
      surface: lightBg,
      onSurface: lightPrimary,
      surfaceContainer: lightPanel,
      surfaceContainerHigh: lightElevated,
      onSurfaceVariant: lightMuted,
      outline: lightBorder,
      outlineVariant: lightBorder,
      error: danger,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: lightPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: lightPanel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: lightBorder),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: lightPanel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: lightBorder),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: lightPanel,
        indicatorColor: lightElevated,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: lightOnPrimary,
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: lightElevated,
        side: BorderSide(color: lightBorder),
      ),
      dividerColor: lightBorder,
      pageTransitionsTheme: _pageTransitions,
    );
  }
}

class _DployGoPageTransitionsBuilder extends PageTransitionsBuilder {
  const _DployGoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst ||
        MediaQuery.maybeOf(context)?.disableAnimations == true) {
      return child;
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: .985, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}

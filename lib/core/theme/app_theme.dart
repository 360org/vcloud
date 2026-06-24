import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// VCloud design tokens — premium / "tech" refresh: vivid blue→indigo brand
/// gradient, vibrant per-feature accents, layered soft shadows with colored
/// glow. Use these everywhere so the look stays consistent and is easy to
/// retheme for the Odoo integration.
class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF2B5BF0); // vivid blue
  static const primaryDeep = Color(0xFF4F46E5); // indigo (gradient end)
  static const primaryViolet = Color(0xFF7C3AED);
  static const primarySoft = Color(0xFFEAF0FF); // tinted backgrounds

  // Semantic
  static const success = Color(0xFF16A34A);
  static const successLight = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const dangerDeep = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);

  // Per-feature accents (kept vivid for striking stat tiles)
  static const chat = Color(0xFF3B82F6);
  static const timesheet = Color(0xFF8B5CF6);
  static const ticket = Color(0xFFFB923C);
  static const calendar = Color(0xFF06B6D4); // cyan — "tech"

  // Neutrals
  static const bg = Color(0xFFF3F5FB); // cool light app background
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE9EDF5);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  // ---- gradients ----------------------------------------------------------
  static const brand = LinearGradient(
    colors: [primary, primaryDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const brandWide = LinearGradient(
    colors: [Color(0xFF2B5BF0), Color(0xFF6D5DF0)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const successGrad = LinearGradient(
    colors: [successLight, success],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// A two-stop gradient that brightens [c] — used for accent icon chips.
  static LinearGradient accent(Color c) => LinearGradient(
        colors: [Color.lerp(c, Colors.white, 0.18)!, c],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Soft tinted background for an accent (badges, chips).
  static Color soft(Color c) =>
      Color.alphaBlend(c.withValues(alpha: 0.12), surface);

  /// Colored glow shadow for elevated/branded elements.
  static List<BoxShadow> glow(Color c, {double opacity = 0.35}) => [
        BoxShadow(
          color: c.withValues(alpha: opacity),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];
}

/// Shared card decoration: white, rounded, layered soft shadow.
BoxDecoration cardDecoration({Color? color, double radius = 18}) =>
    BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border, width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
        BoxShadow(
          color: Color(0x14101828),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    );

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.surface,
    brightness: Brightness.light,
  ).copyWith(
    error: AppColors.danger,
    onSurface: AppColors.textPrimary,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F4FA),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    dividerTheme: const DividerThemeData(
        color: AppColors.border, space: 1, thickness: 1),
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Dark theme mirrors the light brand for now (design spec is light-only).
ThemeData buildDarkTheme() => buildLightTheme();

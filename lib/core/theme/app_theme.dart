import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// VCloud design tokens — "Refined Tech Luxury" refresh: deep indigo-to-midnight
/// gradients, glassmorphism cards, per-feature gradient accents, grain texture.
/// Use these everywhere so the look stays consistent and is easy to retheme.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────
  static const primary = Color(0xFF2B5BF0);
  static const primaryDeep = Color(0xFF4F46E5);
  static const primaryViolet = Color(0xFF7C3AED);
  static const primarySoft = Color(0xFFEAF0FF);

  // ── Midnight tones (for gradients / dark surfaces) ─────────────────────
  static const midnight = Color(0xFF0F1629);
  static const midnightLight = Color(0xFF1A2340);
  static const midnightCard = Color(0xFF1E2A4A);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const success = Color(0xFF16A34A);
  static const successLight = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const dangerDeep = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);

  // ── Per-feature accents ────────────────────────────────────────────────
  static const chat = Color(0xFF3B82F6);
  static const chatDeep = Color(0xFF06B6D4);
  static const timesheet = Color(0xFF8B5CF6);
  static const timesheetDeep = Color(0xFFA855F7);
  static const ticket = Color(0xFFFB923C);
  static const ticketDeep = Color(0xFFF59E0B);
  static const calendar = Color(0xFF06B6D4);
  static const calendarDeep = Color(0xFF0891B2);
  static const attendance = Color(0xFF10B981);
  static const attendanceDeep = Color(0xFF059669);
  
  // ── Soft tint backgrounds ────────────────────────────────────────────────────
  static const chatSoft = Color(0xFFEFF6FF);
  static const timesheetSoft = Color(0xFFF2EBFE);
  static const ticketSoft = Color(0xFFFFF0F2);
  static const calendarSoft = Color(0xFFF0FDFF);
  static const attendanceSoft = Color(0xFFEFFCF3);

  // ── Neutrals ───────────────────────────────────────────────────────────
  static const bg = Color(0xFFF3F5FB);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE9EDF5);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  // ── Glass effect ───────────────────────────────────────────────────────
  static const glassBg = Color(0x0FFFFFFF); // white 6%
  static const glassBorder = Color(0x15FFFFFF); // white 8%
  static const glassBgDark = Color(0x0A000000); // black 4%

  // ── Dark mode tokens ───────────────────────────────────────────────────
  static const darkBg = Color(0xFF0F1729);
  static const darkSurface = Color(0xFF1A2340);
  static const darkBorder = Color(0xFF2A3A5C);
  static const darkTextPrimary = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkTextMuted = Color(0xFF64748B);
  static const darkGlassBg = Color(0x15FFFFFF); // white 8%
  static const darkGlassBorder = Color(0x20FFFFFF); // white 12%

  // ── Gradients ──────────────────────────────────────────────────────────
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
  static const midnightGrad = LinearGradient(
    colors: [midnight, midnightLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Per-feature gradient pairs for screens
  static const chatGrad = LinearGradient(
    colors: [chat, chatDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const timesheetGrad = LinearGradient(
    colors: [timesheet, timesheetDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const ticketGrad = LinearGradient(
    colors: [ticket, ticketDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const calendarGrad = LinearGradient(
    colors: [calendar, calendarDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const attendanceGrad = LinearGradient(
    colors: [attendance, attendanceDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Per-feature gradient pair.
  static LinearGradient featureGrad(Color c, Color deep) => LinearGradient(
        colors: [c, deep],
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

  /// Subtle glow for glass cards.
  static List<BoxShadow> glassGlow(Color c, {double opacity = 0.15}) => [
        BoxShadow(
          color: c.withValues(alpha: opacity),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        const BoxShadow(
          color: Color(0x080F172A),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  /// Enhanced glow for premium elements
  static List<BoxShadow> premiumGlow(Color c, {double opacity = 0.25}) => [
        BoxShadow(
          color: c.withValues(alpha: opacity),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: c.withValues(alpha: opacity * 0.6),
          blurRadius: 40,
          offset: const Offset(0, 20),
        ),
      ];

  /// Soft background for feature highlighting
  static Color featureBackground(Color c) =>
      Color.alphaBlend(c.withValues(alpha: 0.04), surface);

  /// Stronger soft background for emphasis
  static Color featureBackgroundStrong(Color c) =>
      Color.alphaBlend(c.withValues(alpha: 0.08), surface);

  /// Medium soft background for subtle emphasis
  static Color featureBackgroundMedium(Color c) =>
      Color.alphaBlend(c.withValues(alpha: 0.06), surface);
}

/// Glass card decoration — frosted glass effect with subtle border.
BoxDecoration glassDecoration({
  Color? color,
  double radius = 20,
  double opacity = 0.06,
}) =>
    BoxDecoration(
      color: AppColors.surface.withValues(alpha: opacity + 0.88),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppColors.border.withValues(alpha: 0.6),
        width: 0.5,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x060F172A),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
        BoxShadow(
          color: Color(0x10101828),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    );

/// Legacy card decoration — kept for backward compatibility.
BoxDecoration cardDecoration({Color? color, double radius = 18}) =>
    glassDecoration(color: color, radius: radius);

/// Enhanced glass card decoration for premium visual depth
BoxDecoration premiumGlassDecoration({
  Color? color,
  double radius = 28,
  double opacity = 0.12,
}) =>
    BoxDecoration(
      color: AppColors.surface.withValues(alpha: opacity + 0.9),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppColors.border.withValues(alpha: 0.8),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.15),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: AppColors.midnight.withValues(alpha: 0.2),
          blurRadius: 40,
          offset: const Offset(0, 20),
        ),
      ],
    );

/// Shared text styles for consistent typography across the app.
class AppTextStyles {
  AppTextStyles._();

  static const display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.4,
  );

  static const subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.4,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.3,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.3,
  );

  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    height: 1.2,
  );
}

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

/// Dark theme with midnight-based color scheme.
ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.darkSurface,
    brightness: Brightness.dark,
  ).copyWith(
    error: AppColors.danger,
    onSurface: AppColors.darkTextPrimary,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.darkBg,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.darkTextPrimary,
      displayColor: AppColors.darkTextPrimary,
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
      color: AppColors.darkSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkBg,
      hintStyle: const TextStyle(color: AppColors.darkTextMuted),
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
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.darkTextMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder, space: 1, thickness: 1),
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

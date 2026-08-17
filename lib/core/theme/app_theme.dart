import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// VCloud design tokens — World360 green refresh with glassmorphism cards,
/// per-feature gradient accents, and a clean mobile-first palette.
/// Use these everywhere so the look stays consistent and is easy to retheme.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────
  static const primary = Color(0xFF00C83A);
  static const primaryDeep = Color(0xFF009D2E);
  static const primaryViolet = Color(0xFF0077D9);
  static const primarySoft = Color(0xFFE7FBEA);

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
  static const timesheet = Color(0xFF00C83A);
  static const timesheetDeep = Color(0xFF009D2E);
  static const ticket = Color(0xFFFB923C);
  static const ticketDeep = Color(0xFFF59E0B);
  static const calendar = Color(0xFF06B6D4);
  static const calendarDeep = Color(0xFF0891B2);
  static const attendance = Color(0xFF10B981);
  static const attendanceDeep = Color(0xFF059669);

  // ── Soft tint backgrounds ────────────────────────────────────────────────────
  static const chatSoft = Color(0xFFEFF6FF);
  static const timesheetSoft = Color(0xFFE7FBEA);
  static const ticketSoft = Color(0xFFFFF0F2);
  static const calendarSoft = Color(0xFFF0FDFF);
  static const attendanceSoft = Color(0xFFEFFCF3);

  // ── Neutrals ───────────────────────────────────────────────────────────
  static const bg = Color(0xFFF1F8F2);
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
  static const darkSurfaceElevated = Color(0xFF222E52);
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
    colors: [Color(0xFF00C83A), Color(0xFF0077D9)],
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
  static Color soft(Color c, {bool isDark = false}) =>
      Color.alphaBlend(c.withValues(alpha: isDark ? 0.18 : 0.12), isDark ? darkSurface : surface);

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
  static Color featureBackground(Color c, {bool isDark = false}) =>
      Color.alphaBlend(c.withValues(alpha: isDark ? 0.08 : 0.04), isDark ? darkSurface : surface);

  /// Stronger soft background for emphasis
  static Color featureBackgroundStrong(Color c, {bool isDark = false}) =>
      Color.alphaBlend(c.withValues(alpha: isDark ? 0.14 : 0.08), isDark ? darkSurface : surface);

  /// Medium soft background for subtle emphasis
  static Color featureBackgroundMedium(Color c, {bool isDark = false}) =>
      Color.alphaBlend(c.withValues(alpha: isDark ? 0.10 : 0.06), isDark ? darkSurface : surface);

  /// Odoo's `color_index` palette (0–11) as used by `helpdesk.tag.color`.
  /// Index `0` is white/no-color and intentionally omitted — see [odooTagColor].
  static const _odooColorPalette = <int, Color>{
    1: Color(0xFFF06050), // red
    2: Color(0xFFFAAA38), // orange
    3: Color(0xFFF7E928), // yellow
    4: Color(0xFFA8D245), // light green
    5: Color(0xFF51BBE5), // light blue
    6: Color(0xFF7D7D7D), // gray
    7: Color(0xFF7C7BAD), // medium purple
    8: Color(0xFF825F5F), // brown
    9: Color(0xFFC24668), // dark pink
    10: Color(0xFF1F8E76), // dark teal
    11: Color(0xFF0F8FA9), // cyan
  };

  /// Resolve an arbitrary tag-color value coming from Odoo (an index 0–11,
  /// a `#RRGGBB` string, or `null`) into a real [Color]. Falls back to
  /// [textMuted] so the UI never blows up on a colour it can't recognise.
  static Color odooTagColor(Object? value) {
    if (value is num) {
      final c = _odooColorPalette[value.toInt()];
      if (c != null) return c;
    } else if (value is String && value.isNotEmpty) {
      var hex = value.trim();
      if (hex.startsWith('#')) hex = hex.substring(1);
      if (hex.length == 6 && int.tryParse(hex, radix: 16) != null) {
        return Color(0xFF000000 | int.parse(hex, radix: 16));
      }
    }
    return textMuted;
  }

  /// Turn a 6-char hex string (with or without leading `#`) into a [Color].
  /// Invalid input returns `null` so callers can decide the fallback.
  static Color? fromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var clean = hex.trim();
    if (clean.startsWith('#')) clean = clean.substring(1);
    if (clean.length != 6) return null;
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}

/// Extension on [BuildContext] for clean, adaptive theme color resolution.
extension AppThemeContextExtension on BuildContext {
  /// Whether the current theme mode is dark.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Primary text color based on active theme mode.
  Color get textColor => isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;

  /// Secondary text color based on active theme mode.
  Color get textSecondary => isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;

  /// Muted text color based on active theme mode.
  Color get textMuted => isDarkMode ? AppColors.darkTextMuted : AppColors.textMuted;

  /// Card/surface color based on active theme mode.
  Color get cardColor => isDarkMode ? AppColors.darkSurface : AppColors.surface;

  /// Scaffold background color based on active theme mode.
  Color get bgColor => isDarkMode ? AppColors.darkBg : AppColors.bg;

  /// Border color based on active theme mode.
  Color get borderColor => isDarkMode ? AppColors.darkBorder : AppColors.border;

  /// Soft tinted background color adaptive to active theme.
  Color softColor(Color color) => AppColors.soft(color, isDark: isDarkMode);
}

/// Glass card decoration — frosted glass effect with subtle border.
BoxDecoration glassDecoration({
  Color? color,
  double radius = 20,
  double opacity = 0.06,
  bool isDark = false,
}) => BoxDecoration(
  color: (color ?? (isDark ? AppColors.darkSurface : AppColors.surface)).withValues(alpha: opacity + 0.88),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(
    color: (isDark ? AppColors.darkBorder : AppColors.border).withValues(alpha: 0.6),
    width: 0.5,
  ),
  boxShadow: [
    BoxShadow(
      color: isDark ? const Color(0x20000000) : const Color(0x060F172A),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: isDark ? const Color(0x30000000) : const Color(0x10101828),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ],
);

/// Legacy card decoration — kept for backward compatibility.
BoxDecoration cardDecoration({Color? color, double radius = 18, bool isDark = false}) =>
    glassDecoration(color: color, radius: radius, isDark: isDark);

/// Enhanced glass card decoration for premium visual depth
BoxDecoration premiumGlassDecoration({
  Color? color,
  double radius = 28,
  double opacity = 0.12,
  bool isDark = false,
}) => BoxDecoration(
  color: (color ?? (isDark ? AppColors.darkSurface : AppColors.surface)).withValues(alpha: opacity + 0.9),

  borderRadius: BorderRadius.circular(radius),
  border: Border.all(
    color: (isDark ? AppColors.darkBorder : AppColors.border).withValues(alpha: 0.8),
    width: 1,
  ),
  boxShadow: [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.15),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: (isDark ? Colors.black : AppColors.midnight).withValues(alpha: 0.25),
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
  ).copyWith(error: AppColors.danger, onSurface: AppColors.textPrimary);

  final base = ThemeData(
    useMaterial3: true,
    splashFactory: InkRipple.splashFactory,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
      color: AppColors.border,
      space: 1,
      thickness: 1,
    ),
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
    surfaceContainerHigh: AppColors.darkSurface,
    surfaceContainer: AppColors.darkSurface,
  );

  final base = ThemeData(
    useMaterial3: true,
    splashFactory: InkRipple.splashFactory,
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
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.darkBorder, width: 0.8),
      ),
      titleTextStyle: const TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.darkTextSecondary,
        fontSize: 14,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      modalBackgroundColor: AppColors.darkSurface,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.darkSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder, width: 0.8),
      ),
      textStyle: const TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkSurface,
      disabledColor: AppColors.darkBg,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      secondarySelectedColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      labelStyle: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 12),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 12),
      brightness: Brightness.dark,
      side: const BorderSide(color: AppColors.darkBorder, width: 0.6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      hintStyle: const TextStyle(color: AppColors.darkTextMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkBorder),
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
      color: AppColors.darkBorder,
      space: 1,
      thickness: 1,
    ),
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

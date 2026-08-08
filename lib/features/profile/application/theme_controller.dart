import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_preferences_repository.dart';

final userPreferencesRepositoryProvider = Provider<UserPreferencesRepository>(
  (_) => UserPreferencesRepository(),
);

enum AppThemeMode { light, dark, system }

class ThemeController extends AsyncNotifier<AppThemeMode> {
  @override
  Future<AppThemeMode> build() async {
    final prefs = ref.read(userPreferencesRepositoryProvider);
    final data = await prefs.getPreferences();
    final theme = data['theme'] as String? ?? 'light';
    return _parseTheme(theme);
  }

  AppThemeMode _parseTheme(String theme) {
    switch (theme) {
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
        return AppThemeMode.system;
      default:
        return AppThemeMode.light;
    }
  }

  String _themeToString(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.system:
        return 'system';
      case AppThemeMode.light:
        return 'light';
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final prefs = ref.read(userPreferencesRepositoryProvider);
      await prefs.updateTheme(_themeToString(mode));
      return mode;
    });
  }
}

final themeControllerProvider =
    AsyncNotifierProvider<ThemeController, AppThemeMode>(ThemeController.new);

extension AppThemeModeX on AppThemeMode {
  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.system:
        final hour = DateTime.now().hour;
        // Theo giờ Việt Nam (UTC+7):
        // Từ 06:00 sáng đến 18:00 tối -> Giao diện Sáng (Light Mode)
        // Từ 18:00 tối đến 06:00 sáng -> Giao diện Tối (Dark Mode)
        if (hour >= 6 && hour < 18) {
          return ThemeMode.light;
        } else {
          return ThemeMode.dark;
        }
    }
  }

  String get displayName {
    switch (this) {
      case AppThemeMode.dark:
        return 'Tối';
      case AppThemeMode.system:
        return 'Hệ thống';
      case AppThemeMode.light:
        return 'Sáng';
    }
  }
}

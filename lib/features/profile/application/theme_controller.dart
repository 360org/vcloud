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
    final theme = data['theme'] as String? ?? 'system';
    return _parseTheme(theme);
  }

  AppThemeMode _parseTheme(String theme) {
    switch (theme) {
      case 'dark':
        return AppThemeMode.dark;
      case 'light':
        return AppThemeMode.light;
      case 'system':
      default:
        return AppThemeMode.system;
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
        // Chuẩn Native OS: Trả về ThemeMode.system để Flutter engine tự động
        // lắng nghe platformDispatcher.platformBrightness của hệ điều hành
        return ThemeMode.system;
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

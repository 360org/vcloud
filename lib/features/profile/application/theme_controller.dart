import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_preferences_repository.dart';

final userPreferencesRepositoryProvider = Provider<UserPreferencesRepository>(
  (_) => UserPreferencesRepository(),
);

enum AppThemeMode {
  vuahethong,
  light,
  dark,
  system,
}

class ThemeController extends AsyncNotifier<AppThemeMode> {
  String _serverColorScheme = 'light';

  @override
  Future<AppThemeMode> build() async {
    final prefs = ref.read(userPreferencesRepositoryProvider);
    final data = await prefs.getPreferences();
    _serverColorScheme = data['server_color_scheme'] as String? ?? 'light';
    final theme = data['theme'] as String? ?? 'vuahethong';
    return _parseTheme(theme);
  }

  AppThemeMode _parseTheme(String theme) {
    switch (theme) {
      case 'vuahethong':
        return AppThemeMode.vuahethong;
      case 'dark':
        return AppThemeMode.dark;
      case 'light':
        return AppThemeMode.light;
      case 'system':
        return AppThemeMode.system;
      default:
        return AppThemeMode.vuahethong;
    }
  }

  String _themeToString(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.vuahethong:
        return 'vuahethong';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.system:
        return 'system';
      case AppThemeMode.light:
        return 'light';
    }
  }

  ThemeMode resolveThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.vuahethong:
        return _serverColorScheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
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

  Future<void> syncServerTheme(String? colorScheme) async {
    if (colorScheme == null || colorScheme.isEmpty) return;
    final normalized = colorScheme.toLowerCase().contains('dark') ? 'dark' : 'light';
    _serverColorScheme = normalized;
    final prefs = ref.read(userPreferencesRepositoryProvider);
    await prefs.updateServerColorScheme(normalized);
    // Nếu đang ở chế độ đồng bộ theo Vua Hệ Thống, trigger cập nhật UI ngay lập tức
    final current = state.valueOrNull ?? AppThemeMode.vuahethong;
    if (current == AppThemeMode.vuahethong) {
      state = AsyncValue.data(current);
    }
  }
}

final themeControllerProvider =
    AsyncNotifierProvider<ThemeController, AppThemeMode>(ThemeController.new);

final currentThemeModeProvider = Provider<ThemeMode>((ref) {
  final appThemeAsync = ref.watch(themeControllerProvider);
  final notifier = ref.read(themeControllerProvider.notifier);
  return appThemeAsync.when(
    data: (mode) => notifier.resolveThemeMode(mode),
    loading: () => ThemeMode.light,
    error: (e, st) => ThemeMode.light,
  );
});

extension AppThemeModeX on AppThemeMode {
  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.vuahethong:
        return ThemeMode.light;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  String get displayName {
    switch (this) {
      case AppThemeMode.vuahethong:
        return 'Đồng bộ Vua Hệ Thống';
      case AppThemeMode.light:
        return 'Sáng';
      case AppThemeMode.dark:
        return 'Tối';
      case AppThemeMode.system:
        return 'Theo thiết bị di động';
    }
  }
}

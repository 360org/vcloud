import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserPreferencesRepository {
  UserPreferencesRepository([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  static const _themeKey = 'vcloud_user_theme';
  static const _serverColorSchemeKey = 'vcloud_server_color_scheme';
  static const _languageKey = 'vcloud_user_language';

  Map<String, dynamic> _prefs = <String, dynamic>{
    'theme': 'vuahethong',
    'server_color_scheme': 'light',
    'language': 'vi',
  };
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final theme = await _storage.read(key: _themeKey) ?? 'vuahethong';
      final serverScheme = await _storage.read(key: _serverColorSchemeKey) ?? 'light';
      final lang = await _storage.read(key: _languageKey) ?? 'vi';
      _prefs = {
        'theme': theme,
        'server_color_scheme': serverScheme,
        'language': lang,
      };
      _initialized = true;
    } catch (_) {
      _initialized = true;
    }
  }

  Future<Map<String, dynamic>> getPreferences() async {
    await _ensureInitialized();
    return Map<String, dynamic>.from(_prefs);
  }

  Future<void> updateTheme(String theme) async {
    await _ensureInitialized();
    _prefs = <String, dynamic>{..._prefs, 'theme': theme};
    try {
      await _storage.write(key: _themeKey, value: theme);
    } catch (_) {}
  }

  Future<void> updateServerColorScheme(String colorScheme) async {
    await _ensureInitialized();
    _prefs = <String, dynamic>{..._prefs, 'server_color_scheme': colorScheme};
    try {
      await _storage.write(key: _serverColorSchemeKey, value: colorScheme);
    } catch (_) {}
  }

  Future<void> updateLanguage(String language) async {
    await _ensureInitialized();
    _prefs = <String, dynamic>{..._prefs, 'language': language};
    try {
      await _storage.write(key: _languageKey, value: language);
    } catch (_) {}
  }
}

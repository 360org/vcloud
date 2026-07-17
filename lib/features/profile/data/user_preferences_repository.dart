class UserPreferencesRepository {
  Map<String, dynamic> _prefs = <String, dynamic>{
    'theme': 'system',
    'language': 'vi',
  };

  Future<Map<String, dynamic>> getPreferences() async {
    return Map<String, dynamic>.from(_prefs);
  }

  Future<void> updateTheme(String theme) async {
    _prefs = <String, dynamic>{..._prefs, 'theme': theme};
  }

  Future<void> updateLanguage(String language) async {
    _prefs = <String, dynamic>{..._prefs, 'language': language};
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';

class UserPreferencesRepository {
  UserPreferencesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> getPreferences() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw Failure('Not signed in');

    final res = await _client
        .from('user_preferences')
        .select('*')
        .eq('user_id', me)
        .maybeSingle();

    if (res == null) {
      final newRes = await _client
          .from('user_preferences')
          .insert({'user_id': me})
          .select()
          .single();
      return Map<String, dynamic>.from(newRes);
    }

    return Map<String, dynamic>.from(res);
  }

  Future<void> updateTheme(String theme) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw Failure('Not signed in');

    await _client.from('user_preferences').upsert({
      'user_id': me,
      'theme': theme,
    });
  }

  Future<void> updateLanguage(String language) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw Failure('Not signed in');

    await _client.from('user_preferences').upsert({
      'user_id': me,
      'language': language,
    });
  }
}

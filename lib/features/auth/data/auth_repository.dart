import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/auth_user.dart';
import '../../../core/api/odoo_api_client.dart';
import '../../../core/api/odoo_session.dart';
import '../../../core/error/failure.dart';

/// Thin facade around Odoo auth. All auth flows in the app go
/// through here so controllers do not talk to HTTP directly.
class AuthRepository {
  AuthRepository({OdooApiClient? client, FlutterSecureStorage? storage})
      : _client = client ?? odooApiClient,
        _storage = storage ?? const FlutterSecureStorage();

  final OdooApiClient _client;
  final FlutterSecureStorage _storage;

  Future<AuthUser?> currentUser() async {
    final session = await _client.restoreSession();
    return session == null ? null : _toUser(session);
  }

  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
    int? tenantId,
  }) {
    return signIn(email: email, password: password, tenantId: tenantId);
  }

  Future<AuthUser> signIn({
    required String email,
    required String password,
    int? tenantId,
  }) async {
    try {
      final session = await _client.login(
        login: email,
        password: password,
        tenantId: tenantId,
      );
      return _toUser(session);
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure('Login failed: ${e.toString()}');
    }
  }

  Future<void> signOut() {
    return _client.logout();
  }

  Future<void> saveLocalAvatar(String uid, String avatarData) async {
    await _storage.write(key: 'custom_avatar_$uid', value: avatarData);
  }

  Future<String?> getLocalAvatar(String uid) async {
    return await _storage.read(key: 'custom_avatar_$uid');
  }

  Future<String> uploadAvatar(String base64Image) async {
    try {
      final res = await _client.post(
        '/api/v1/mobile/avatar/upload',
        body: <String, dynamic>{'avatar': base64Image},
      );
      if (res is Map && res['avatar_url'] != null) {
        return res['avatar_url'].toString();
      }
    } catch (_) {}
    return '';
  }

  Future<AuthUser> _toUser(OdooSession session) async {
    final profile = await _currentUserProfile(session.uid);
    final partnerId = (session.partnerId ?? _many2OneId(profile?['partner_id']))
        ?.toString();
    final name = _stringOrNull(profile?['name']);
    final login = _stringOrNull(profile?['login']) ?? session.login;
    final companyName = _stringOrNull(profile?['company_name']);
    var function = _stringOrNull(profile?['job_title'] ?? profile?['function']);

    if ((function == null || function.isEmpty) && partnerId != null) {
      try {
        final contactRes = await _client.get('/api/v1/mobile/contacts/$partnerId');
        if (contactRes is Map) {
          function = _stringOrNull(contactRes['function']);
        }
      } catch (_) {}
    }

    final metadata = <String, dynamic>{
      'display_name': name ?? login.split('@').first,
      'db': session.db,
    };
    if (partnerId != null) metadata['partner_id'] = partnerId;
    if (companyName != null) metadata['company'] = companyName;
    if (function != null && function.isNotEmpty) metadata['role'] = function;

    // Check local storage for persistent custom avatar
    final localAvatar = await getLocalAvatar(session.uid.toString());

    final isValidLocal = localAvatar != null &&
        localAvatar.trim().isNotEmpty &&
        localAvatar != 'false' &&
        localAvatar != 'null' &&
        (localAvatar.startsWith('data:image') ||
            localAvatar.startsWith('http://') ||
            localAvatar.startsWith('https://') ||
            localAvatar.startsWith('/'));

    final avatar = isValidLocal
        ? localAvatar
        : (_stringOrNull(
            profile?['avatar_url'] ??
                profile?['avatar_128_url'] ??
                profile?['image_128_url'] ??
                profile?['avatar_128'] ??
                profile?['image_128'] ??
                profile?['image'],
          ) ?? '/web/image/res.users/${session.uid}/avatar_128');

    metadata['avatar_url'] = avatar;

    return AuthUser(
      id: session.uid.toString(),
      email: login,
      userMetadata: metadata,
    );
  }

  Future<Map<String, dynamic>?> _currentUserProfile(int uid) async {
    try {
      final res = await _client.currentUserProfile();
      if (res != null) return res;
    } catch (_) {
      try {
        await _client.refreshSession();
        final res = await _client.currentUserProfile();
        if (res != null) return res;
      } catch (_) {
        // Fall through to model endpoints for older gateways.
      }
    }
    try {
      final res = await _client.get(
        '/api/v1/res.users/$uid',
        query: const <String, Object?>{'fields': 'id,login,name,partner_id'},
      );
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (_) {
      // Older gateways may not expose a single-record res.users endpoint.
    }
    try {
      final res = await _client.get(
        '/api/v1/res.users',
        query: const <String, Object?>{'fields': 'id,login,name,partner_id'},
      );
      final users = (res as List? ?? const <dynamic>[]).whereType<Map>().map(
        (user) => Map<String, dynamic>.from(user),
      );
      for (final user in users) {
        if (user['id']?.toString() == uid.toString()) return user;
      }
    } catch (_) {
      // Auth should still work even if metadata enrichment is unavailable.
    }
    return null;
  }

  static String? _many2OneId(Object? value) {
    if (value == null || value == false) return null;
    if (value is List && value.isNotEmpty) return value.first.toString();
    if (value is Map && value['id'] != null) return value['id'].toString();
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static String? _stringOrNull(Object? value) {
    if (value == null || value == false) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}

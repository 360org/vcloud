import '../../../core/api/auth_user.dart';
import '../../../core/api/odoo_api_client.dart';
import '../../../core/api/odoo_session.dart';
import '../../../core/error/failure.dart';

/// Thin facade around Odoo auth. All auth flows in the app go
/// through here so controllers do not talk to HTTP directly.
class AuthRepository {
  AuthRepository({OdooApiClient? client}) : _client = client ?? odooApiClient;

  final OdooApiClient _client;

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
    // The provided gateway exposes login, not registration. Keep the existing
    // screen functional for provisioned Odoo users by logging in.
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

  Future<AuthUser> _toUser(OdooSession session) async {
    final profile = await _currentUserProfile(session.uid);
    final partnerId = (session.partnerId ?? _many2OneId(profile?['partner_id']))
        ?.toString();
    final name = _stringOrNull(profile?['name']);
    final login = _stringOrNull(profile?['login']) ?? session.login;
    final metadata = <String, dynamic>{
      'display_name': name ?? login.split('@').first,
      'db': session.db,
    };
    if (partnerId != null) metadata['partner_id'] = partnerId;
    final avatar = _stringOrNull(
      profile?['avatar_url'] ??
          profile?['avatar_128_url'] ??
          profile?['image_128_url'] ??
          profile?['avatar_128'] ??
          profile?['image_128'] ??
          profile?['image'],
    );
    if (avatar != null) {
      metadata['avatar_url'] = avatar;
    }

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

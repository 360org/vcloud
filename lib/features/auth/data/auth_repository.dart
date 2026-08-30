import 'dart:async';

import 'package:flutter/foundation.dart';
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
    if (session == null) return null;
    try {
      final profile = await _client.currentUserProfile();
      if (profile == null) {
        debugPrint('[AuthRepository.currentUser] Profile null → logout');
        await _client.logout();
        return null;
      }
    } catch (e, st) {
      debugPrint('[AuthRepository.currentUser] Session invalid on backend: $e\n$st');
      await _client.logout();
      return null;
    }
    return _toUser(session);
  }

  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
    int? tenantId,
  }) {
    return signIn(email: email, password: password, tenantId: tenantId);
  }

  static const _savedEmailKey = 'saved_login_email';

  Future<void> saveLastLoginEmail(String email) async {
    try {
      final trimmed = email.trim();
      if (trimmed.isNotEmpty) {
        await _storage.write(key: _savedEmailKey, value: trimmed);
      }
    } catch (e, st) {
      debugPrint('[AuthRepository.saveLastLoginEmail] Error: $e\n$st');
    }
  }

  Future<String?> getLastLoginEmail() async {
    try {
      return await _storage.read(key: _savedEmailKey);
    } catch (e, st) {
      debugPrint('[AuthRepository.getLastLoginEmail] Error: $e\n$st');
      return null;
    }
  }

  Future<AuthUser> signIn({
    required String email,
    required String password,
    int? tenantId,
  }) async {
    try {
      await saveLastLoginEmail(email);
      final session = await _client.login(
        login: email,
        password: password,
        tenantId: tenantId,
      );
      return await _toUser(session);
    } on Failure {
      rethrow;
    } on TimeoutException {
      debugPrint('🚨 [AuthRepository.signIn] TIMEOUT');
      throw Failure('Lỗi kết nối máy chủ (hết thời gian chờ). Vui lòng thử lại!');
    } catch (e, st) {
      debugPrint('🚨 [AuthRepository.signIn] UNEXPECTED EXCEPTION: $e\n$st');
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
    } catch (e, st) {
      debugPrint('[AuthRepository.uploadAvatar] Error: $e\n$st');
    }
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
      'name': name ?? login.split('@').first,
      'db': session.db,
      'uid': session.uid.toString(),
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

    // Always use /users/ endpoint — /partners/ returns 405 on current server.
    var avatar = isValidLocal
        ? localAvatar
        : '/api/v1/mobile/avatar/users/${session.uid}';

    if (!avatar.startsWith('data:image') &&
        !avatar.contains('access_token=') &&
        !avatar.contains('token=')) {
      final sep = avatar.contains('?') ? '&' : '?';
      avatar = '$avatar${sep}access_token=${session.accessToken}';
    }

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
    } catch (e, st) {
      debugPrint('[AuthRepository._currentUserProfile] /auth/me failed: $e\n$st');
      try {
        await _client.refreshSession();
        final res = await _client.currentUserProfile();
        if (res != null) return res;
      } catch (e2, st2) {
        debugPrint('[AuthRepository._currentUserProfile] refreshSession + retry failed: $e2\n$st2');
        // Fall through to model endpoints for older gateways.
      }
    }
    try {
      final res = await _client.get(
        '/api/v1/res.users/$uid',
        query: const <String, Object?>{'fields': 'id,login,name,partner_id'},
      );
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (e, st) {
      debugPrint('[AuthRepository._currentUserProfile] /api/v1/res.users/$uid failed: $e\n$st');
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
    } catch (e, st) {
      debugPrint('[AuthRepository._currentUserProfile] /api/v1/res.users list failed: $e\n$st');
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

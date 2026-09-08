import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/auth_user.dart';
import '../../../core/api/odoo_api_client.dart';
import '../../../core/api/odoo_session.dart';
import '../../../core/error/failure.dart';
import 'db_info.dart';

/// Thin facade around Odoo auth. All auth flows in the app go
/// through here so controllers do not talk to HTTP directly.
class AuthRepository {
  AuthRepository({OdooApiClient? client, FlutterSecureStorage? storage})
      : _client = client ?? odooApiClient,
        _storage = storage ?? const FlutterSecureStorage();

  final OdooApiClient _client;
  final FlutterSecureStorage _storage;

  // ---------------------------------------------------------------------------
  // [P0/P1] Lookup-DB + Authenticate-On-Client (Directory Routing Architecture)
  // ---------------------------------------------------------------------------

  /// [Giải pháp 2 / Anti-DB Enumeration]: Tra cứu và xác thực với Master Router.
  /// Gửi [login], [password] và [preferredDb] (DB gần nhất) để Master ưu tiên verify song song.
  Future<List<DbInfo>> lookupDb(String login, String password, {String? preferredDb}) async {
    try {
      final rawList = await _client.lookupDb(login, password, preferredDb: preferredDb);
      return rawList.map(DbInfo.fromJson).toList();
    } on Failure {
      rethrow;
    } catch (e, st) {
      debugPrint('[AuthRepository.lookupDb] Unexpected: $e\n$st');
      throw Failure('Không thể tra cứu thông tin tài khoản. Vui lòng thử lại!');
    }
  }

  /// Bước 4 — Xác thực TRỰC TIẾP với Client DB URL.
  /// Password chỉ đến [db.databaseUrl], tuyệt đối không qua Master.
  Future<AuthUser> authenticateOnClient({
    required DbInfo db,
    required String login,
    required String password,
  }) async {
    try {
      await saveLastLoginEmail(login);
      await saveLastSelectedDb(db.databaseName);
      final session = await _client.authenticateOnClient(
        targetBaseUrl: db.databaseUrl,
        dbName: db.databaseName,
        login: login,
        password: password,
      );
      return await _toUser(session);
    } on Failure {
      rethrow;
    } on TimeoutException {
      debugPrint('🚨 [AuthRepository.authenticateOnClient] TIMEOUT');
      throw Failure(
          'Lỗi kết nối máy chủ (hết thời gian chờ). Vui lòng thử lại!');
    } catch (e, st) {
      debugPrint(
          '🚨 [AuthRepository.authenticateOnClient] UNEXPECTED: $e\n$st');
      throw Failure('Đăng nhập thất bại: ${e.toString()}');
    }
  }

  // ---------------------------------------------------------------------------
  // Existing API — giữ nguyên để không phá vỡ các flow khác
  // ---------------------------------------------------------------------------

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
      debugPrint(
          '[AuthRepository.currentUser] Session invalid on backend: $e\n$st');
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
  static const _savedDbKey = 'saved_last_database';

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

  Future<void> saveLastSelectedDb(String dbName) async {
    try {
      final trimmed = dbName.trim();
      if (trimmed.isNotEmpty) {
        await _storage.write(key: _savedDbKey, value: trimmed);
      }
    } catch (e, st) {
      debugPrint('[AuthRepository.saveLastSelectedDb] Error: $e\n$st');
    }
  }

  Future<String?> getLastSelectedDb() async {
    try {
      return await _storage.read(key: _savedDbKey);
    } catch (e, st) {
      debugPrint('[AuthRepository.getLastSelectedDb] Error: $e\n$st');
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
      throw Failure(
          'Lỗi kết nối máy chủ (hết thời gian chờ). Vui lòng thử lại!');
    } catch (e, st) {
      debugPrint('🚨 [AuthRepository.signIn] UNEXPECTED EXCEPTION: $e\n$st');
      throw Failure('Login failed: ${e.toString()}');
    }
  }

  Future<void> signOut() {
    return _client.logout();
  }

  Future<void> saveLocalAvatar(String uid, String avatarData, {String? db}) async {
    final key = (db != null && db.isNotEmpty)
        ? 'custom_avatar_${db}_$uid'
        : 'custom_avatar_${_client.session?.db ?? ""}_$uid';
    await _storage.write(key: key, value: avatarData);
  }

  Future<String?> getLocalAvatar(String uid, {String? db}) async {
    final key = (db != null && db.isNotEmpty)
        ? 'custom_avatar_${db}_$uid'
        : 'custom_avatar_${_client.session?.db ?? ""}_$uid';
    return await _storage.read(key: key);
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
    final hasVMobile = session.scope != 'odoo_web_session';
    final profile = hasVMobile ? await _currentUserProfile(session.uid) : null;
    final partnerId =
        (session.partnerId ?? _many2OneId(profile?['partner_id']))?.toString();
    final name = _stringOrNull(profile?['name']);
    final login = _stringOrNull(profile?['login']) ?? session.login;
    final companyName = _stringOrNull(profile?['company_name']);
    var function =
        _stringOrNull(profile?['job_title'] ?? profile?['function']);

    if (hasVMobile && (function == null || function.isEmpty) && partnerId != null) {
      try {
        final contactRes =
            await _client.get('/api/v1/mobile/contacts/$partnerId');
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
      'has_v_mobile': hasVMobile,
    };
    if (partnerId != null) metadata['partner_id'] = partnerId;
    if (companyName != null) metadata['company'] = companyName;
    if (function != null && function.isNotEmpty) metadata['role'] = function;

    // Xác định phân loại Database & Version
    final lowerDb = session.db.toLowerCase();
    final lowerUrl = session.baseUrl.toLowerCase();
    final is19 = lowerDb.contains('19') || lowerUrl.contains(':8079') || lowerUrl.contains('demo.vuahethong');
    final isCustomer = lowerDb.contains('client') || lowerDb.contains('customer');
    final dbTypeLabel = is19
        ? '🚀 Odoo 19 (Prod/Demo)'
        : (isCustomer ? '👥 Khách Hàng (Odoo 17)' : '🏢 Nội Bộ (Odoo 17)');

    // In Terminal Log trực quan để Sếp theo dõi Database đang hoạt động
    debugPrint('''
╔══════════════════════════════════════════════════════════════════╗
║ 🚀 [VCLOUD AUTH SUCCESS] ĐĂNG NHẬP THÀNH CÔNG                    ║
╠══════════════════════════════════════════════════════════════════╣
║ 👤 Tài khoản : $login (UID: ${session.uid})
║ 🗄️ Database  : ${session.db} [$dbTypeLabel]
║ 🏢 Công ty   : ${companyName ?? 'Mặc định'}
║ 🌐 Server URL: ${session.baseUrl}
║ 🔑 Auth Mode : ${session.scope != null && session.scope!.isNotEmpty ? session.scope : 'JWT/Session'}
╚══════════════════════════════════════════════════════════════════╝''');

    final localAvatar = await getLocalAvatar(session.uid.toString(), db: session.db);

    final isValidLocal = localAvatar != null &&
        localAvatar.trim().isNotEmpty &&
        localAvatar != 'false' &&
        localAvatar != 'null' &&
        (localAvatar.startsWith('data:image') ||
            localAvatar.startsWith('http://') ||
            localAvatar.startsWith('https://') ||
            localAvatar.startsWith('/'));

    // Ưu tiên:
    // 1. Avatar local người dùng tự tải lên
    // 2. avatar_url / avatar_128_url từ profile backend trả về (đối với DB có vmobile)
    // 3. Fallback theo chuẩn Mobile API /api/v1/mobile/avatar/res.users/$uid
    final serverAvatar = _stringOrNull(profile?['avatar_url'] ?? profile?['avatar_128_url'] ?? profile?['image_128_url']);

    var avatar = isValidLocal
        ? localAvatar
        : (serverAvatar != null && serverAvatar.isNotEmpty
            ? serverAvatar
            : (hasVMobile ? '/api/v1/mobile/avatar/res.users/${session.uid}' : ''));

    if (avatar.isNotEmpty &&
        !avatar.startsWith('data:image') &&
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
      debugPrint(
          '[AuthRepository._currentUserProfile] /auth/me failed: $e\n$st');
      try {
        await _client.refreshSession();
        final res = await _client.currentUserProfile();
        if (res != null) return res;
      } catch (e2, st2) {
        debugPrint(
            '[AuthRepository._currentUserProfile] refreshSession + retry failed: $e2\n$st2');
      }
    }
    try {
      final res = await _client.get(
        '/api/v1/res.users/$uid',
        query: const <String, Object?>{'fields': 'id,login,name,partner_id'},
      );
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (e, st) {
      debugPrint(
          '[AuthRepository._currentUserProfile] /api/v1/res.users/$uid failed: $e\n$st');
    }
    try {
      final res = await _client.get(
        '/api/v1/res.users',
        query: const <String, Object?>{'fields': 'id,login,name,partner_id'},
      );
      final users = (res as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((user) => Map<String, dynamic>.from(user));
      for (final user in users) {
        if (user['id']?.toString() == uid.toString()) return user;
      }
    } catch (e, st) {
      debugPrint(
          '[AuthRepository._currentUserProfile] /api/v1/res.users list failed: $e\n$st');
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

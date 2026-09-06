import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../error/failure.dart';
import 'odoo_session.dart';
import 'odoo_session_store.dart';

Object? _parseJsonPayload(String text) => jsonDecode(text);

Uint8List _decodeBase64(String encoded) => base64Decode(encoded);


/// One selectable tenant returned by the master auth resolver when the same
/// `login`/`password` is accepted by multiple Odoo databases (HTTP 409
/// `multiple_tenants`). The user picks one and the client re-authenticates by
/// sending its [tenantId] back to `/api/v1/mobile/auth/login`.
class TenantChoice {
  const TenantChoice({
    required this.tenantId,
    required this.name,
    this.db,
    this.baseUrl,
    this.scope,
  });

  final int tenantId;
  final String name;
  final String? db;
  final String? baseUrl;
  final String? scope;

  factory TenantChoice.fromJson(Map<String, dynamic> json) => TenantChoice(
        tenantId: _intOrZero(json['tenant_id']),
        name: (json['name'] ?? json['db'] ?? '').toString(),
        db: _nonEmptyString(json['db']),
        baseUrl: _nonEmptyString(json['base_url']),
        scope: _nonEmptyString(json['scope']),
      );

  static List<TenantChoice> listFromJson(Object? raw) {
    if (raw is! List) return const <TenantChoice>[];
    return raw
        .whereType<Map>()
        .map((e) => TenantChoice.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  static int _intOrZero(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static String? _nonEmptyString(Object? value) {
    final text = value?.toString();
    if (text == null) return null;
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Thrown by [OdooApiClient] when the master auth resolver answers
/// `409 multiple_tenants` — the credentials belong to more than one database
/// and the user must choose which tenant to sign in to. Carries the candidate
/// [TenantChoice]s so the UI can show a picker and retry with `tenant_id`.
/// Falls back to the plain `Failure` path when the body is malformed or lacks
/// a tenant list.
class MultipleTenantsFailure extends Failure {
  MultipleTenantsFailure(this.tenants)
      : super(
          'Tài khoản thuộc nhiều tenant. Vui lòng chọn tenant trước khi đăng nhập.',
        );

  final List<TenantChoice> tenants;
}

class TenantNotFoundFailure extends Failure {
  TenantNotFoundFailure()
      : super(
          'Chưa cấu hình tenant cho tài khoản này. Vui lòng tạo mapping trong Mobile API > Tenant Users.',
        );
}

class OdooApiClient {
  static void Function()? onSessionExpired;

  OdooApiClient({
    http.Client? httpClient,
    OdooSessionStore? sessionStore,
    String? baseUrl,
  }) : _http = httpClient ?? http.Client(),
       _sessionStore = sessionStore ?? OdooSessionStore(),
       _baseUrl = (baseUrl ?? Env.odooApiBaseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       );

  final http.Client _http;
  final OdooSessionStore _sessionStore;
  final String _baseUrl;

  OdooSession? _session;
  final Map<String, String> _partnerToUserMap = {};

  OdooSession? get session => _session;

  void registerPartnerUserMapping(Object? partnerId, Object? userId) {
    if (partnerId != null && userId != null) {
      final pStr = partnerId.toString().trim();
      final uStr = userId.toString().trim();
      if (pStr.isNotEmpty && uStr.isNotEmpty && pStr != '0' && uStr != '0') {
        _partnerToUserMap[pStr] = uStr;
      }
    }
  }

  String? getUserIdForPartner(String partnerId) {
    return _partnerToUserMap[partnerId.trim()];
  }

  String absoluteUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '${_activeBaseUrl()}$normalized';
  }

  /// Transforms [path] into an absolute URL and attaches `access_token` query
  /// parameter if not present and a session token or [accessToken] is available.
  String authenticatedUrl(String path, {String? accessToken}) {
    final absUrl = absoluteUrl(path);
    final token = (accessToken != null && accessToken.isNotEmpty)
        ? accessToken
        : _session?.accessToken;
    if (token == null || token.isEmpty) return absUrl;

    final uri = Uri.parse(absUrl);
    if (uri.queryParameters.containsKey('access_token')) return absUrl;

    final params = Map<String, String>.from(uri.queryParameters);
    params['access_token'] = token;
    return uri.replace(queryParameters: params).toString();
  }

  /// Chuẩn hoá và trả về URL ảnh avatar tuyệt đối hợp lệ.
  /// Trả về `null` nếu URL rỗng, 'false', 'null', 'undefined'.
  String? resolveAvatarUrl(String? rawUrl, {String? accessToken}) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty ||
        trimmed == 'false' ||
        trimmed == 'null' ||
        trimmed == 'undefined') {
      return null;
    }
    if (trimmed.startsWith('data:image') ||
        (!trimmed.contains('/') && trimmed.length > 80)) {
      return trimmed;
    }
    return authenticatedUrl(trimmed, accessToken: accessToken);
  }

  /// Map containing Authorization Bearer header for HTTP network requests.
  Map<String, String>? get authHeaders {
    final token = _session?.accessToken;
    if (token == null || token.isEmpty) return null;
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  Future<OdooSession?> restoreSession() async {
    final stored = await _sessionStore.read();
    if (stored == null || stored.isExpired) {
      await _sessionStore.clear();
      _session = null;
      return null;
    }
    // Tự động vô hiệu hóa session khi chuyển đổi giữa các database khác nhau (vd: demo-17 vs demo-19)
    if (Env.odooDb.isNotEmpty && stored.db.isNotEmpty && stored.db != Env.odooDb) {
      await _sessionStore.clear();
      _session = null;
      return null;
    }
    _session = stored;
    return stored;
  }

  Future<OdooSession> login({
    required String login,
    required String password,
    int? tenantId,
  }) async {
    final trimmedLogin = login.trim();
    final primaryBaseUrl = _baseUrl.isNotEmpty ? _baseUrl : Env.odooApiBaseUrl;
    const demoBaseUrl = 'https://demo.vuahethong.com';

    // Nếu người dùng đã chỉ định rõ tenantId (từ popup chọn tổ chức)
    if (tenantId != null) {
      final targetUrl = tenantId == 9999 ? demoBaseUrl : primaryBaseUrl;
      final session = await _tryFullLoginAt(
        targetBaseUrl: targetUrl,
        login: trimmedLogin,
        password: password,
        targetDb: tenantId == 9999 ? 'demo' : null,
        tenantId: tenantId == 9999 ? null : tenantId,
        timeout: const Duration(seconds: 12),
      );
      _session = session;
      await _sessionStore.write(session);
      return session;
    }

    // Nếu primaryBaseUrl không phải là vuahethong.net (ví dụ: tenant URL, custom master hoặc demo)
    if (primaryBaseUrl != 'https://vuahethong.net') {
      final session = await _tryFullLoginAt(
        targetBaseUrl: primaryBaseUrl,
        login: trimmedLogin,
        password: password,
        targetDb: primaryBaseUrl.contains('demo.vuahethong.com') ? 'demo' : null,
        timeout: const Duration(seconds: 12),
      );
      _session = session;
      await _sessionStore.write(session);
      return session;
    }

    // Email nội bộ / công ty: Chỉ gọi thẳng primary (vuahethong.net) và fail fast
    final isCompanyEmail = trimmedLogin.contains('@360.org.vn') ||
        trimmedLogin.contains('@vuahethong.net');
    if (isCompanyEmail) {
      final session = await _tryFullLoginAt(
        targetBaseUrl: primaryBaseUrl,
        login: trimmedLogin,
        password: password,
        timeout: const Duration(seconds: 12),
      );
      _session = session;
      await _sessionStore.write(session);
      return session;
    }

    // Gửi đồng thời kiểm tra cả 2 domain (Parallel Multi-Domain Check)
    OdooSession? primarySession;
    Object? primaryErr;
    OdooSession? demoSession;
    Object? demoErr;

    await Future.wait([
      _tryFullLoginAt(
        targetBaseUrl: primaryBaseUrl,
        login: trimmedLogin,
        password: password,
        timeout: const Duration(seconds: 12),
      ).then<void>(
        (s) => primarySession = s,
        onError: (e) => primaryErr = e,
      ),
      _tryFullLoginAt(
        targetBaseUrl: demoBaseUrl,
        login: trimmedLogin,
        password: password,
        targetDb: 'demo',
        timeout: const Duration(seconds: 8),
      ).then<void>(
        (s) => demoSession = s,
        onError: (e) => demoErr = e,
      ),
    ]);

    // Trường hợp 1: CẢ 2 DOMAIN ĐỀU ĐĂNG NHẬP ĐƯỢC (Trùng tài khoản & mật khẩu)
    if (primarySession != null && demoSession != null) {
      final tenants = [
        TenantChoice(
          tenantId: 1,
          name: 'Vua Hệ Thống (Chính thức)',
          db: primarySession!.db,
          baseUrl: primaryBaseUrl,
        ),
        const TenantChoice(
          tenantId: 9999,
          name: 'Trung tâm Trải nghiệm & Demo',
          db: 'demo',
          baseUrl: demoBaseUrl,
        ),
      ];
      throw MultipleTenantsFailure(tenants);
    }

    // Trường hợp 2: Chỉ thành công ở Primary (vuahethong.net)
    if (primarySession != null) {
      _session = primarySession;
      await _sessionStore.write(primarySession!);
      return primarySession!;
    }

    // Trường hợp 3: Chỉ thành công ở Demo (demo.vuahethong.com)
    if (demoSession != null) {
      _session = demoSession;
      await _sessionStore.write(demoSession!);
      return demoSession!;
    }

    // Trường hợp 4: Cả 2 đều thất bại
    if (primaryErr is MultipleTenantsFailure) {
      throw primaryErr!;
    }
    if (primaryErr is TenantNotFoundFailure) {
      throw primaryErr!;
    }
    if (primaryErr != null) {
      throw primaryErr!;
    }
    if (demoErr != null) {
      throw demoErr!;
    }

    throw Failure('Tài khoản hoặc mật khẩu không chính xác. Vui lòng kiểm tra lại!');
  }

  Future<OdooSession> _tryFullLoginAt({
    required String targetBaseUrl,
    required String login,
    required String password,
    String? targetDb,
    int? tenantId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final dbName = targetDb ??
        (targetBaseUrl.contains('demo')
            ? 'demo'
            : Env.odooDb);
    try {
      return await _attemptLoginAt(
        targetBaseUrl: targetBaseUrl,
        login: login,
        password: password,
        targetDb: dbName,
        tenantId: tenantId,
        timeout: timeout,
      );
    } on MultipleTenantsFailure {
      rethrow;
    } on TenantNotFoundFailure catch (e) {
      if (tenantId != null) rethrow;
      try {
        return await _loginMasterAdmin(login: login, password: password);
      } catch (masterErr, masterSt) {
        debugPrint('🚨 [_tryFullLoginAt] Master admin fallback failed: $masterErr\n$masterSt');
        throw e;
      }
    } catch (e, st) {
      debugPrint('🚨 [_tryFullLoginAt] Primary attempt failed for $targetBaseUrl: $e\n$st');
      if (e.toString().toLowerCase().contains('database not found')) {
        final isLocal = targetBaseUrl.contains('127.0.0.1') || targetBaseUrl.contains('localhost');
        if (isLocal) {
          final altDb = (dbName == 'demo-19') ? 'demo-17' : 'demo-19';
          try {
            return await _attemptLoginAt(
              targetBaseUrl: targetBaseUrl,
              login: login,
              password: password,
              targetDb: altDb,
              tenantId: tenantId,
              timeout: timeout,
            );
          } catch (altErr, altSt) {
            debugPrint('🚨 [_tryFullLoginAt] AltDb ($altDb) fallback failed: $altErr\n$altSt');
          }
        }
      }
      try {
        final fallbackDb = dbName.isNotEmpty ? dbName : 'vuahethong';
        return await _loginWithOdooSessionAndJwtAt(
          targetBaseUrl: targetBaseUrl,
          login: login,
          password: password,
          dbName: fallbackDb,
          tenantId: tenantId,
          timeout: timeout,
        );
      } catch (fallbackErr, fallbackSt) {
        debugPrint('🚨 [_tryFullLoginAt] JWT/Session fallback failed: $fallbackErr\n$fallbackSt');
        rethrow;
      }
    }
  }

  String get activeBaseUrl => _activeBaseUrl();

  /// [P0 / Security]: Tra cứu danh sách Client DB từ Master (`https://vuahethong.net/api/v1/auth/lookup-db`).
  /// CHỈ gửi duy nhất field `login`, tuyệt đối KHÔNG chứa password.
  Future<List<Map<String, dynamic>>> lookupDb(String login) async {
    final masterUrl = _baseUrl.isNotEmpty ? _baseUrl : 'https://vuahethong.net';
    final uri = Uri.parse('$masterUrl/api/v1/auth/lookup-db');

    final response = await _http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'login': login.trim()}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Failure('Không thể tra cứu thông tin hệ thống (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['error'] != null) {
      final err = decoded['error'];
      final msg = err is Map ? (err['message'] ?? err['data']?['message']) : null;
      throw Failure(msg?.toString() ?? 'Lỗi tra cứu thông tin tài khoản.');
    }

    List rawList = [];
    if (decoded is Map && decoded['result'] is List) {
      rawList = decoded['result'] as List;
    } else if (decoded is List) {
      rawList = decoded;
    }

    return rawList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// [P0 / Security]: Xác thực TRỰC TIẾP tới Client DB URL.
  /// Password chỉ được gửi đến Client DB, KHÔNG đi qua Master.
  Future<OdooSession> authenticateOnClient({
    required String targetBaseUrl,
    required String dbName,
    required String login,
    required String password,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final cleanBaseUrl = targetBaseUrl.replaceFirst(RegExp(r'/$'), '');
    final authUri = Uri.parse('$cleanBaseUrl/web/session/authenticate');

    final authPayload = {
      'jsonrpc': '2.0',
      'params': {
        'db': dbName,
        'login': login.trim(),
        'password': password,
      },
    };

    final authResponse = await _http
        .post(
          authUri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(authPayload),
        )
        .timeout(timeout);

    if (authResponse.statusCode != 200) {
      throw Failure(
        'Không thể kết nối đến máy chủ ($cleanBaseUrl) - mã lỗi ${authResponse.statusCode}',
      );
    }

    final authDecoded = jsonDecode(authResponse.body);
    if (authDecoded is! Map || authDecoded['error'] != null) {
      final err = authDecoded is Map ? authDecoded['error'] : null;
      final errMsg =
          err is Map ? (err['data']?['message'] ?? err['message']) : null;
      throw Failure(
        errMsg?.toString() ?? 'Mật khẩu không chính xác. Vui lòng kiểm tra lại!',
      );
    }

    final authResult = authDecoded['result'];
    if (authResult is! Map) {
      throw Failure('Tài khoản hoặc mật khẩu không chính xác.');
    }

    final uid = _intOrNull(authResult['uid']);
    if (uid == null || uid == 0) {
      throw Failure('Mật khẩu không chính xác.');
    }
    final partnerId = _intOrNull(authResult['partner_id']);

    String? sessionId;
    final rawCookies = authResponse.headers['set-cookie'];
    if (rawCookies != null) {
      final match = RegExp(r'session_id=([^;]+)').firstMatch(rawCookies);
      if (match != null) {
        sessionId = match.group(1);
      }
    }

    final session = OdooSession(
      accessToken: sessionId ?? 'session_$uid',
      refreshToken: null,
      uid: uid,
      db: dbName,
      login: login.trim(),
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
      baseUrl: cleanBaseUrl,
      tenantId: null,
      scope: 'odoo_web_session',
      partnerId: partnerId,
    );

    _session = session;
    await _sessionStore.write(session);
    return session;
  }

  Future<OdooSession> _attemptLoginAt({
    required String targetBaseUrl,
    required String login,
    required String password,
    required String targetDb,
    int? tenantId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final body = <String, dynamic>{'login': login, 'password': password};
    if (targetDb.isNotEmpty) body['db'] = targetDb;
    if (tenantId != null) body['tenant_id'] = tenantId;

    final uri = Uri.parse('$targetBaseUrl/api/v1/mobile/auth/login');
    final response = await _http
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    final text = response.body;
    Object? decoded;
    if (text.isNotEmpty) {
      try {
        decoded = jsonDecode(text);
      } catch (e, st) {
        debugPrint('🚨 [_attemptLoginAt] JSON parse failed. Status: ${response.statusCode}, Body: $text\n$e\n$st');
        if (response.statusCode >= 400) {
          throw Failure('Máy chủ phản hồi lỗi (${response.statusCode}).');
        }
        throw Failure('Dữ liệu từ máy chủ không đúng định dạng.');
      }
    }

    final multiTenants = _tryMultipleTenants(decoded, response.statusCode);
    if (multiTenants != null) throw multiTenants;
    final tenantNotFound = _tryTenantNotFound(decoded, response.statusCode);
    if (tenantNotFound != null) throw tenantNotFound;

    if (response.statusCode >= 400 ||
        decoded is! Map ||
        decoded['error'] != null) {
      throw Failure(_errorMessage(decoded, response.statusCode));
    }

    return _sessionFromJson(
      Map<String, dynamic>.from(decoded),
      fallbackLogin: login,
      fallbackDb: targetDb,
      fallbackBaseUrl: targetBaseUrl,
    );
  }

  Future<OdooSession> _loginWithOdooSessionAndJwtAt({
    required String targetBaseUrl,
    required String login,
    required String password,
    required String dbName,
    int? tenantId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final authUri = Uri.parse('$targetBaseUrl/web/session/authenticate');
    final authPayload = {
      'jsonrpc': '2.0',
      'params': {
        'db': dbName,
        'login': login,
        'password': password,
      },
    };
    final authResponse = await _http
        .post(
          authUri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(authPayload),
        )
        .timeout(timeout);

    if (authResponse.statusCode != 200) {
      throw Failure(
        'Không thể kết nối đến máy chủ Odoo (${authResponse.statusCode})',
      );
    }
    final authDecoded = jsonDecode(authResponse.body);
    if (authDecoded is! Map || authDecoded['error'] != null) {
      final err = authDecoded is Map ? authDecoded['error'] : null;
      final errMsg =
          err is Map ? (err['data']?['message'] ?? err['message']) : null;
      throw Failure(
        errMsg?.toString() ?? 'Tài khoản hoặc mật khẩu không chính xác.',
      );
    }
    final authResult = authDecoded['result'];
    if (authResult is! Map) {
      throw Failure('Tài khoản hoặc mật khẩu không chính xác.');
    }
    final uid = _intOrNull(authResult['uid']);
    if (uid == null || uid == 0) {
      throw Failure('Tài khoản hoặc mật khẩu không chính xác.');
    }
    final partnerId = _intOrNull(authResult['partner_id']);

    String? sessionId;
    final rawCookies = authResponse.headers['set-cookie'];
    if (rawCookies != null) {
      final match = RegExp(r'session_id=([^;]+)').firstMatch(rawCookies);
      if (match != null) {
        sessionId = match.group(1);
      }
    }

    // Step 2: Gửi request lấy JWT access_token có kèm session_id cookie
    final jwtUri = Uri.parse('$targetBaseUrl/api/v1/mobile/auth/login');
    final jwtHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (sessionId != null) 'Cookie': 'session_id=$sessionId',
    };
    final jwtBody = <String, dynamic>{
      'login': login,
      'password': password,
      'db': dbName,
    };
    if (tenantId != null) {
      jwtBody['tenant_id'] = tenantId;
    }

    try {
      final jwtResponse = await _http
          .post(
            jwtUri,
            headers: jwtHeaders,
            body: jsonEncode(jwtBody),
          )
          .timeout(timeout);
      if (jwtResponse.statusCode == 200) {
        final jwtDecoded = jsonDecode(jwtResponse.body);
        if (jwtDecoded is Map && jwtDecoded['access_token'] != null) {
          return _sessionFromJson(
            Map<String, dynamic>.from(jwtDecoded),
            fallbackLogin: login,
            fallbackDb: dbName,
            fallbackBaseUrl: targetBaseUrl,
            fallbackUid: uid,
            fallbackPartnerId: partnerId,
          );
        }
      }
      debugPrint('🚨 [_loginWithOdooSessionAndJwtAt] JWT step2 status=${jwtResponse.statusCode}, body=${jwtResponse.body.length > 500 ? jwtResponse.body.substring(0, 500) : jwtResponse.body}');
    } catch (e, st) {
      debugPrint('🚨 [_loginWithOdooSessionAndJwtAt] JWT step2 failed: $e\n$st');
    }

    return OdooSession(
      accessToken: sessionId ?? 'session_$uid',
      refreshToken: null,
      uid: uid,
      db: dbName,
      login: login,
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
      baseUrl: targetBaseUrl,
      tenantId: null,
      scope: 'odoo_web_session',
      partnerId: partnerId,
    );
  }

  Future<OdooSession> _loginMasterAdmin({
    required String login,
    required String password,
  }) async {
    final body = <String, dynamic>{
      'login': login,
      'password': password,
      if (Env.odooDb.isNotEmpty) 'db': Env.odooDb,
    };
    final res = await post('/api/v1/auth/login', body: body, auth: false);
    final map = _responseMap(res);
    map.putIfAbsent('base_url', () => _baseUrl);
    map.putIfAbsent('scope', () => 'master_admin');
    map.putIfAbsent('login', () => login);
    final session = _sessionFromJson(
      map,
      fallbackLogin: login,
      fallbackDb: Env.odooDb,
      fallbackBaseUrl: _baseUrl,
    );
    _session = session;
    await _sessionStore.write(session);
    return session;
  }

  Future<void> logout() async {
    final refreshToken = _session?.refreshToken;
    if (_session != null) {
      try {
        await post(
          '/api/v1/auth/logout',
          body: <String, dynamic>{
            if (refreshToken != null && refreshToken.isNotEmpty)
              'refresh_token': refreshToken,
          },
        );
      } catch (_) {}
    }
    _session = null;
    await _sessionStore.clear();
  }

  Future<OdooSession?> refreshSession() async {
    if (_session == null) await restoreSession();
    if (_session == null) return null;
    final json = await post('/api/v1/auth/refresh');
    final session = _sessionFromJson(
      Map<String, dynamic>.from(json as Map),
      fallbackLogin: _session!.login,
      fallbackDb: _session!.db,
      fallbackBaseUrl: _session!.baseUrl,
      fallbackUid: _session!.uid,
      fallbackPartnerId: _session!.partnerId,
    );
    _session = session;
    await _sessionStore.write(session);
    return session;
  }

  Future<Map<String, dynamic>?> currentUserProfile() async {
    final res = await get('/api/v1/auth/me');
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }

  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) {
    return _send('GET', path, query: query, auth: auth);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) {
    return _send('POST', path, body: body, query: query, auth: auth);
  }

  Future<dynamic> put(String path, {Object? body}) {
    return _send('PUT', path, body: body);
  }

  Future<dynamic> delete(String path) {
    return _send('DELETE', path);
  }

  /// Fetches raw binary bytes (images, files) from `path`. Unlike [get]/[post],
  /// which JSON-decode the body, this returns the raw [Uint8List] so callers can
  /// download attachments, forward them by re-uploading, or save to disk.
  /// Uses the same session-guard and bearer auth as [_send].
  Future<Uint8List> fetchBytes(String path) async {
    if (_session == null || _session!.isExpired) {
      await restoreSession();
    }
    if (_session == null) throw Failure('Not signed in');

    final uri = Uri.parse(absoluteUrl(path));
    final headers = <String, String>{
      'Accept': '*/*',
      if (_session != null) 'Authorization': 'Bearer ${_session!.accessToken}',
    };
    
    try {
      final response = await _http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint('==================================================');
        debugPrint('📥 RAW HTTP RESPONSE DIAGNOSTICS');
        debugPrint('Target Path/URL: $path');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint(
          'Content-Type Header: ${response.headers['content-type'] ?? "unknown"}',
        );
        debugPrint('All Headers: ${response.headers}');

        try {
          final bodyStr = response.body;
          final bodyPreview = bodyStr.length > 500
              ? '${bodyStr.substring(0, 500)}...'
              : bodyStr;
          debugPrint('Body Preview (Text): $bodyPreview');
        } catch (e) {
          debugPrint('Failed to read response body as text: $e');
        }

        debugPrint('Raw BodyBytes Length: ${response.bodyBytes.length}');
        debugPrint('==================================================');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Failure('Request failed (${response.statusCode}).');
      }

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';

      // Binary fast-path: For raw image/stream data, return binary bytes directly without calling response.body (avoids UTF-8 decode exception)
      if (contentType.startsWith('image/') ||
          contentType == 'application/octet-stream' ||
          contentType == 'application/pdf') {
        return response.bodyBytes;
      }

      // Defensive Parsing: Check if JSON or base64 wrapped response
      String bodyStr = '';
      try {
        bodyStr = response.body;
      } catch (_) {
        return response.bodyBytes;
      }

      final trimmedBody = bodyStr.trimLeft();
      if (contentType.contains('application/json') || trimmedBody.startsWith('{') || trimmedBody.startsWith('[')) {
        try {
          final decoded = jsonDecode(bodyStr);
          if (decoded is Map) {
            final result = decoded['result'] ?? decoded['data'] ?? decoded['attachment'] ?? decoded['file'];
            if (result is Map) {
              final base64String = result['datas'] ?? result['data'] ?? result['base64'] ?? result['content'];
              if (base64String is String && base64String.isNotEmpty) {
                return await compute(_decodeBase64, base64String);
              }
            } else if (result is String && result.isNotEmpty && !result.startsWith('{')) {
              return await compute(_decodeBase64, result);
            }
            final topBase64 = decoded['datas'] ?? decoded['base64'] ?? decoded['content'];
            if (topBase64 is String && topBase64.isNotEmpty) {
              return await compute(_decodeBase64, topBase64);
            }
          }
        } catch (_) {}
      }

      // Fallback: Return raw binary bytes directly
      return response.bodyBytes;
    } catch (e, stackTrace) {
      dev.log('Failed to fetch or parse bytes payload: $e', name: 'OdooApi', error: e, stackTrace: stackTrace);
      throw Failure('Lỗi tải tệp: $e');
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    if (auth && (_session == null || _session!.isExpired)) {
      await restoreSession();
    }
    if (auth && _session == null) {
      onSessionExpired?.call();
      throw Failure('Not signed in');
    }

    final queryParameters = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    final baseUri = Uri.parse('${_requestBaseUrl(auth: auth)}$path');
    final uri = queryParameters.isEmpty
        ? baseUri
        : baseUri.replace(queryParameters: queryParameters);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (auth) 'Authorization': 'Bearer ${_session!.accessToken}',
    };

    if (kDebugMode) {
      dev.log('HTTP $method ${uri.replace(query: '')}', name: 'OdooApiClient');
    }

    const timeout = Duration(seconds: 30);
    final http.Response response;
    try {
      response = await switch (method) {
        'GET' => _http.get(uri, headers: headers).timeout(timeout),
        'POST' => _http
            .post(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(timeout),
        'PUT' => _http
            .put(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(timeout),
        'DELETE' => _http.delete(uri, headers: headers).timeout(timeout),
        _ => throw StateError('Unsupported HTTP method $method'),
      };
    } on TimeoutException {
      throw Failure('Hết thời gian chờ phản hồi từ máy chủ (${timeout.inSeconds}s).');
    }

    final text = response.body;
    Object? decoded;
    if (text.isNotEmpty) {
      try {
        if (text.length > 102400) {
          decoded = await compute(_parseJsonPayload, text);
        } else {
          decoded = jsonDecode(text);
        }
      } catch (_) {
        if (response.statusCode >= 400) {
          throw Failure('Máy chủ phản hồi lỗi (${response.statusCode}).');
        }
        throw Failure('Dữ liệu từ máy chủ không đúng định dạng.');
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (auth && response.statusCode == 401) {
        // Thử refresh token trước khi logout — tránh bị đá vô login loop.
        final refreshed = await _tryRefreshSession();
        if (refreshed) {
          return _send(method, path, body: body, query: query, auth: auth);
        }
        await _sessionStore.clear();
        _session = null;
        onSessionExpired?.call();
      }
      final multiTenants = _tryMultipleTenants(decoded, response.statusCode);
      if (multiTenants != null) throw multiTenants;
      final tenantNotFound = _tryTenantNotFound(decoded, response.statusCode);
      if (tenantNotFound != null) throw tenantNotFound;
      throw Failure(_errorMessage(decoded, response.statusCode));
    }
    return decoded;
  }

  /// Cố gắng refresh token silent. Trả về `true` nếu refresh thành công.
  bool _isRefreshing = false;

  Future<bool> _tryRefreshSession() async {
    // Nếu đang có request khác refresh rồi thì đợi nó.
    if (_isRefreshing) {
      // Đơn giản: đợi rồi kiểm tra session mới hơn không.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return _session != null && !(_session?.isExpired ?? true);
    }
    _isRefreshing = true;
    try {
      final hasRefreshToken = _session?.refreshToken != null &&
          _session!.refreshToken!.isNotEmpty;
      if (!hasRefreshToken) return false;

      final refreshed = await refreshSession();
      return refreshed != null;
    } catch (e) {
      debugPrint('[AuthController] Silent refresh failed: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// When the master resolver returns `409 multiple_tenants` with a tenant
  /// list, surface it as a typed [MultipleTenantsFailure] so the UI can show a
  /// picker. Returns `null` when the body is not that shape so the caller keeps
  /// using the generic [Failure] path.
  static MultipleTenantsFailure? _tryMultipleTenants(
    Object? decoded,
    int statusCode,
  ) {
    if (statusCode != 409 || decoded is! Map) return null;
    if (decoded['error']?.toString() != 'multiple_tenants') return null;
    final tenants = TenantChoice.listFromJson(decoded['tenants']);
    if (tenants.isEmpty) return null;
    return MultipleTenantsFailure(tenants);
  }

  static TenantNotFoundFailure? _tryTenantNotFound(
    Object? decoded,
    int statusCode,
  ) {
    if (statusCode != 404 || decoded is! Map) return null;
    if (decoded['error']?.toString() != 'tenant_not_found') return null;
    return TenantNotFoundFailure();
  }

  static Map<String, dynamic> _responseMap(Object? res) {
    if (res is! Map) {
      throw Failure('Phản hồi đăng nhập không hợp lệ.');
    }
    final map = Map<String, dynamic>.from(res);
    final nested = map['session'] ?? map['data'] ?? map['result'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return map;
  }

  static String _errorMessage(Object? decoded, int statusCode) {
    if (decoded is Map) {
      final code = decoded['error']?.toString();
      final knownMessage = switch (code) {
        'invalid_credentials' =>
          'Tài khoản hoặc mật khẩu không chính xác. Vui lòng kiểm tra lại.',
        'missing_login_or_password' =>
          'Vui lòng nhập đầy đủ email và mật khẩu.',
        'tenant_not_found' =>
          'Chưa cấu hình tenant cho tài khoản này. Vui lòng tạo mapping trong Mobile API > Tenant Users.',
        'multiple_tenants' =>
          'Tài khoản thuộc nhiều tenant. Vui lòng chọn tenant trước khi đăng nhập.',
        'unauthorized' =>
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại (401).',
        'access_denied' =>
          'Bạn không có quyền truy cập chức năng này (403).',
        'method_not_allowed' =>
          'Phương thức yêu cầu không được máy chủ hỗ trợ (405).',
        _ => null,
      };
      if (knownMessage != null) return knownMessage;

      final message =
          decoded['message'] ?? decoded['error'] ?? decoded['detail'];
      if (message != null) return message.toString();
    }

    return switch (statusCode) {
      401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại (401).',
      403 => 'Bạn không có quyền truy cập chức năng này (403).',
      405 => 'Phương thức yêu cầu không được máy chủ hỗ trợ (405).',
      _ => 'Máy chủ phản hồi lỗi ($statusCode).',
    };
  }

  static int? _intOrNull(Object? value) {
    if (value == null || value == false) return null;
    if (value is num) return value.toInt();
    if (value is List && value.isNotEmpty) return _intOrNull(value.first);
    if (value is Map && value['id'] != null) return _intOrNull(value['id']);
    return int.tryParse(value.toString());
  }

  String _requestBaseUrl({required bool auth}) {
    if (!auth) return _baseUrl;
    return _activeBaseUrl();
  }

  String _activeBaseUrl() {
    final baseUrl = _session?.baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) return _baseUrl;
    return baseUrl;
  }

  static String _normalizedBaseUrl(Object? value, String fallback) {
    final text = value?.toString() ?? '';
    final baseUrl = text.isEmpty ? fallback : text;
    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  static OdooSession _sessionFromJson(
    Map<String, dynamic> json, {
    required String fallbackLogin,
    required String fallbackDb,
    required String fallbackBaseUrl,
    int? fallbackUid,
    int? fallbackPartnerId,
  }) {
    final user = json['user'];
    final userMap = user is Map ? user : const <String, dynamic>{};
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 604800;
    return OdooSession(
      accessToken: (json['access_token'] ?? json['token'] ?? json['jwt'])
          .toString(),
      refreshToken: json['refresh_token'] as String?,
      uid:
          _intOrNull(json['uid']) ??
          _intOrNull(userMap['id']) ??
          fallbackUid ??
          0,
      db: (json['db'] as String?) ?? fallbackDb,
      login:
          (json['login'] as String?) ??
          (userMap['login'] as String?) ??
          fallbackLogin,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      baseUrl: _normalizedBaseUrl(json['base_url'], fallbackBaseUrl),
      tenantId: _intOrNull(json['tenant_id']),
      scope: json['scope'] as String?,
      partnerId:
          _intOrNull(json['partner_id']) ??
          _intOrNull(userMap['partner_id']) ??
          fallbackPartnerId,
    );
  }
}

final odooApiClient = OdooApiClient();

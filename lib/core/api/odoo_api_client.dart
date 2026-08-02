import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../error/failure.dart';
import 'odoo_session.dart';
import 'odoo_session_store.dart';

Object? _parseJsonPayload(String text) => jsonDecode(text);



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

  OdooSession? get session => _session;

  String absoluteUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '${_activeBaseUrl()}$normalized';
  }

  Future<OdooSession?> restoreSession() async {
    final stored = await _sessionStore.read();
    if (stored == null || stored.isExpired) {
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
    final body = <String, dynamic>{'login': login, 'password': password};
    if (tenantId != null) body['tenant_id'] = tenantId;
    Object? json;
    try {
      json = await post(
        '/api/v1/mobile/auth/login',
        body: body,
        auth: false,
      );
    } on TenantNotFoundFailure catch (e) {
      if (tenantId != null) rethrow;
      try {
        return await _loginMasterAdmin(login: login, password: password);
      } catch (_) {
        throw e;
      }
    }
    final session = _sessionFromJson(
      Map<String, dynamic>.from(json as Map),
      fallbackLogin: login,
      fallbackDb: Env.odooDb,
      fallbackBaseUrl: _baseUrl,
    );
    _session = session;
    await _sessionStore.write(session);
    return session;
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
    if (_session != null) {
      try {
        await post('/api/v1/auth/logout');
      } catch (_) {
        // Local sign-out must still succeed if the server session is gone.
      }
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
    final response = await _http.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Failure('Request failed (${response.statusCode}).');
    }
    return response.bodyBytes;
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
    if (auth && _session == null) throw Failure('Not signed in');

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

    dev.log(
      'HTTP $method $uri | Payload: ${body != null ? jsonEncode(body) : "none"}',
      name: 'OdooApiClient',
    );

    http.Response response = switch (method) {
      'GET' => await _http.get(uri, headers: headers),
      'POST' => await _http.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      'PUT' => await _http.put(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      'DELETE' => await _http.delete(uri, headers: headers),
      _ => throw StateError('Unsupported HTTP method $method'),
    };

    // Fallback: If server returns 405 Method Not Allowed, retry with alternate method
    if (response.statusCode == 405) {
      dev.log(
        '⚠️ [HTTP 405 METHOD NOT ALLOWED] $method $uri\nResponse Body: ${response.body}',
        name: 'OdooApiClient',
        error: 'HTTP 405 Method Not Allowed',
      );
      if (method == 'GET') {
        final postHeaders = Map<String, String>.from(headers)
          ..['Content-Type'] = 'application/json';
        response = await _http.post(
          uri,
          headers: postHeaders,
          body: jsonEncode(<String, dynamic>{}),
        );
      } else if (method == 'POST') {
        response = await _http.get(uri, headers: headers);
      }
    }




    final text = response.body;
    Object? decoded;
    if (text.isNotEmpty) {
      try {
        if (text.length > 4000) {
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
      if (auth && (response.statusCode == 401 || response.statusCode == 403)) {
        await _sessionStore.clear();
        _session = null;
      }
      final multiTenants = _tryMultipleTenants(decoded, response.statusCode);
      if (multiTenants != null) throw multiTenants;
      final tenantNotFound = _tryTenantNotFound(decoded, response.statusCode);
      if (tenantNotFound != null) throw tenantNotFound;
      throw Failure(_errorMessage(decoded, response.statusCode));
    }
    return decoded;
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

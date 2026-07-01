import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../error/failure.dart';
import 'odoo_session.dart';
import 'odoo_session_store.dart';

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
    return '$_baseUrl$normalized';
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
    String? db,
  }) async {
    final body = <String, dynamic>{
      if ((db ?? Env.odooDb).isNotEmpty) 'db': db ?? Env.odooDb,
      'login': login,
      'password': password,
    };
    final json = await post('/api/v1/auth/login', body: body, auth: false);
    final session = _sessionFromJson(
      Map<String, dynamic>.from(json as Map),
      fallbackLogin: login,
      fallbackDb: db ?? Env.odooDb,
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

    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: {
        for (final entry in query.entries)
          if (entry.value != null) entry.key: entry.value.toString(),
      },
    );
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (auth) 'Authorization': 'Bearer ${_session!.accessToken}',
    };

    final response = switch (method) {
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

    final text = response.body;
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Failure(_errorMessage(decoded, response.statusCode));
    }
    return decoded;
  }

  static String _errorMessage(Object? decoded, int statusCode) {
    if (decoded is Map) {
      final message =
          decoded['message'] ?? decoded['error'] ?? decoded['detail'];
      if (message != null) return message.toString();
    }
    return 'Request failed ($statusCode).';
  }

  static int? _intOrNull(Object? value) {
    if (value == null || value == false) return null;
    if (value is num) return value.toInt();
    if (value is List && value.isNotEmpty) return _intOrNull(value.first);
    if (value is Map && value['id'] != null) return _intOrNull(value['id']);
    return int.tryParse(value.toString());
  }

  static OdooSession _sessionFromJson(
    Map<String, dynamic> json, {
    required String fallbackLogin,
    required String fallbackDb,
    int? fallbackUid,
    int? fallbackPartnerId,
  }) {
    final user = json['user'];
    final userMap = user is Map ? user : const <String, dynamic>{};
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 604800;
    return OdooSession(
      accessToken: (json['access_token'] ?? json['token'] ?? json['jwt'])
          .toString(),
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
      partnerId:
          _intOrNull(json['partner_id']) ??
          _intOrNull(userMap['partner_id']) ??
          fallbackPartnerId,
    );
  }
}

final odooApiClient = OdooApiClient();

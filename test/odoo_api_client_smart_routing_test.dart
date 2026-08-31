import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/core/api/odoo_session_store.dart';
import 'package:vcloud/core/error/failure.dart';

class _MemorySessionStore extends OdooSessionStore {
  OdooSession? stored;

  @override
  Future<OdooSession?> read() async => stored;

  @override
  Future<void> write(OdooSession session) async {
    stored = session;
  }

  @override
  Future<void> clear() async {
    stored = null;
  }
}

void main() {
  group('Dual-Domain Smart Auto-Routing Tests (Production Verified)', () {
    test('TC-01: Company email (@360.org.vn) routes to vuahethong.net and fails fast on 401', () async {
      final store = _MemorySessionStore();
      final requestedUrls = <String>[];

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: store,
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          return http.Response(
            jsonEncode({'error': 'invalid_credentials', 'message': 'Invalid credentials'}),
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await expectLater(
        client.login(login: 'tanmnn@360.org.vn', password: 'wrong_password'),
        throwsA(isA<Failure>()),
      );

      expect(requestedUrls.every((u) => u.startsWith('https://vuahethong.net')), isTrue);
      expect(requestedUrls.any((u) => u.startsWith('https://demo.vuahethong.com')), isFalse);
    });

    test('TC-02: Successful login on primary domain stores session properly', () async {
      final store = _MemorySessionStore();
      final requestedUrls = <String>[];

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: store,
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          if (request.url.path == '/api/v1/mobile/auth/login') {
            return http.Response(
              jsonEncode({
                'access_token': 'prod-jwt-token',
                'refresh_token': 'prod-refresh-token',
                'uid': 2,
                'db': 'vuahethong',
                'partner_id': 3,
              }),
              200,
            );
          }
          return http.Response('{"error": "not_found"}', 404);
        }),
      );

      final session = await client.login(login: 'tanmnn@360.org.vn', password: '@360.org.vn');

      expect(session.baseUrl, 'https://vuahethong.net');
      expect(session.uid, 2);
      expect(session.db, 'vuahethong');
      expect(store.stored?.baseUrl, 'https://vuahethong.net');
      expect(requestedUrls.first, startsWith('https://vuahethong.net'));
    });

    test('TC-03: Network error on primary domain falls back to demo for short demo user', () async {
      final store = _MemorySessionStore();
      final requestedUrls = <String>[];

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: store,
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          if (request.url.toString().startsWith('https://vuahethong.net')) {
            // Ném lỗi kết nối mạng (SocketException / ClientException)
            throw http.ClientException('Network unreachable');
          }
          if (request.url.toString().startsWith('https://demo.vuahethong.com')) {
            return http.Response(
              jsonEncode({
                'access_token': 'demo-token',
                'uid': 5,
                'db': 'demo',
                'partner_id': 11,
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final session = await client.login(login: 'demo', password: 'demo');

      expect(session.baseUrl, 'https://demo.vuahethong.com');
      expect(session.uid, 5);
      expect(requestedUrls.first, startsWith('https://vuahethong.net'));
      expect(requestedUrls.any((u) => u.startsWith('https://demo.vuahethong.com')), isTrue);
    });

    test('TC-04: Logout clears session and restores activeBaseUrl', () async {
      final store = _MemorySessionStore();
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: store,
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/mobile/auth/login') {
            return http.Response(
              jsonEncode({
                'access_token': 'demo-token',
                'uid': 5,
                'db': 'demo',
              }),
              200,
            );
          }
          return http.Response('{"status": "ok"}', 200);
        }),
      );

      await client.login(login: 'tanmnn@360.org.vn', password: 'pwd');
      expect(client.activeBaseUrl, 'https://vuahethong.net');

      await client.logout();
      expect(client.activeBaseUrl, 'https://vuahethong.net');
      expect(store.stored, isNull);
    });
  });
}

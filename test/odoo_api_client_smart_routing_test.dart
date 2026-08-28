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
  group('Dual-Domain Smart Auto-Routing Tests', () {
    test('TC-01: Company email (@360.org.vn) routes ONLY to vuahethong.net and does NOT fallback on 401', () async {
      final store = _MemorySessionStore();
      final requestedUrls = <String>[];

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: store,
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          // Giả lập sai mật khẩu trên Production
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

      // Verify: Toàn bộ request chỉ gọi vuahethong.net, TUYỆT ĐỐI KHÔNG gọi sang demo.vuahethong.com
      expect(requestedUrls.every((u) => u.startsWith('https://vuahethong.net')), isTrue);
      expect(requestedUrls.any((u) => u.startsWith('https://demo.vuahethong.com')), isFalse);
    });

    test('TC-02: Short username without @ (e.g. demo) probes demo.vuahethong.com first', () async {
      final store = _MemorySessionStore();
      final requestedUrls = <String>[];

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: store,
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          if (request.url.toString().startsWith('https://demo.vuahethong.com')) {
            return http.Response(
              jsonEncode({
                'access_token': 'demo-jwt-token',
                'refresh_token': 'demo-refresh-token',
                'uid': 5,
                'db': 'demo',
                'partner_id': 11,
              }),
              200,
            );
          }
          return http.Response('{"error": "not_found"}', 404);
        }),
      );

      final session = await client.login(login: 'demo', password: 'demo');

      // Verify: Được định tuyến vào demo.vuahethong.com
      expect(session.baseUrl, 'https://demo.vuahethong.com');
      expect(session.uid, 5);
      expect(session.db, 'demo');
      expect(store.stored?.baseUrl, 'https://demo.vuahethong.com');
      expect(requestedUrls.first, startsWith('https://demo.vuahethong.com'));
    });

    test('TC-03: Short username fallback to vuahethong.net if demo server fails', () async {
      final store = _MemorySessionStore();
      final requestedUrls = <String>[];

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: store,
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          if (request.url.toString().startsWith('https://demo.vuahethong.com')) {
            return http.Response(
              jsonEncode({'error': 'invalid_credentials'}),
              401,
            );
          }
          if (request.url.toString().startsWith('https://vuahethong.net')) {
            return http.Response(
              jsonEncode({
                'access_token': 'prod-jwt-token',
                'uid': 2,
                'db': 'vuahethong',
                'partner_id': 3,
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final session = await client.login(login: 'admin', password: 'secret');

      expect(session.baseUrl, 'https://vuahethong.net');
      expect(session.uid, 2);
      expect(requestedUrls.length, greaterThanOrEqualTo(2));
      expect(requestedUrls.first, startsWith('https://demo.vuahethong.com'));
    });

    test('TC-04: External email (e.g. client@gmail.com) fallbacks to demo on prod 401', () async {
      final store = _MemorySessionStore();
      final requestedUrls = <String>[];

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: store,
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          if (request.url.toString().startsWith('https://vuahethong.net')) {
            return http.Response(
              jsonEncode({'error': 'invalid_credentials'}),
              401,
            );
          }
          if (request.url.toString().startsWith('https://demo.vuahethong.com')) {
            return http.Response(
              jsonEncode({
                'access_token': 'demo-client-token',
                'uid': 14,
                'db': 'demo',
                'partner_id': 20,
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final session = await client.login(login: 'client@gmail.com', password: 'demo');

      expect(session.baseUrl, 'https://demo.vuahethong.com');
      expect(session.uid, 14);
      expect(requestedUrls.first, startsWith('https://vuahethong.net'));
      expect(requestedUrls.any((u) => u.startsWith('https://demo.vuahethong.com')), isTrue);
    });

    test('TC-05: Logout clears session and resets baseUrl', () async {
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

      await client.login(login: 'demo', password: 'demo');
      expect(client.activeBaseUrl, 'https://demo.vuahethong.com');

      await client.logout();
      expect(client.activeBaseUrl, 'https://vuahethong.net');
      expect(store.stored, isNull);
    });
  });
}

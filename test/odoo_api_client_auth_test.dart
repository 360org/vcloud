import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/core/api/odoo_session_store.dart';
import 'package:vcloud/core/error/failure.dart';

void main() {
  test(
    'login resolves tenant through master and uses tenant base URL',
    () async {
      final store = _MemorySessionStore();
      final requests = <http.Request>[];
      final client = OdooApiClient(
        baseUrl: 'https://master.example.test',
        sessionStore: store,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.toString() ==
              'https://master.example.test/api/v1/mobile/auth/login') {
            expect(jsonDecode(request.body), <String, dynamic>{
              'login': 'demo@example.com',
              'password': 'secret',
            });
            return http.Response(
              jsonEncode(<String, dynamic>{
                'access_token': 'tenant-token',
                'refresh_token': 'refresh-token',
                'uid': 7,
                'db': 'tenant_db',
                'base_url': 'https://tenant.example.test/',
                'tenant_id': 42,
                'scope': 'full',
                'login': 'demo@example.com',
                'expires_in': 604800,
              }),
              200,
            );
          }

          expect(
            request.url.toString(),
            'https://tenant.example.test/api/v1/auth/me',
          );
          expect(request.headers['Authorization'], 'Bearer tenant-token');
          return http.Response('{}', 200);
        }),
      );

      final session = await client.login(
        login: 'demo@example.com',
        password: 'secret',
      );
      await client.get('/api/v1/auth/me');

      expect(requests, hasLength(2));
      expect(session.baseUrl, 'https://tenant.example.test');
      expect(session.tenantId, 42);
      expect(session.scope, 'full');
      expect(store.written?.baseUrl, 'https://tenant.example.test');
    },
  );

  test('login explains missing tenant mapping', () async {
    final client = OdooApiClient(
      baseUrl: 'https://master.example.test',
      sessionStore: _MemorySessionStore(),
      httpClient: MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'error': 'tenant_not_found'}),
          404,
        );
      }),
    );

    await expectLater(
      client.login(login: 'demo@example.com', password: 'secret'),
      throwsA(
        isA<Failure>().having(
          (failure) => failure.message,
          'message',
          contains('Tenant Users'),
        ),
      ),
    );
  });

  test('master admin can fall back to direct master login', () async {
    final store = _MemorySessionStore();
    final requests = <http.Request>[];
    final client = OdooApiClient(
      baseUrl: 'https://master.example.test',
      sessionStore: store,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.toString() ==
            'https://master.example.test/api/v1/mobile/auth/login') {
          return http.Response(
            jsonEncode(<String, dynamic>{'error': 'tenant_not_found'}),
            404,
          );
        }
        expect(
          request.url.toString(),
          'https://master.example.test/api/v1/auth/login',
        );
        expect(jsonDecode(request.body), <String, dynamic>{
          'login': 'admin',
          'password': 'admin-secret',
        });
        return http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'master-token',
            'uid': 1,
            'db': 'master',
            'login': 'admin',
            'expires_in': 604800,
          }),
          200,
        );
      }),
    );

    final session = await client.login(
      login: 'admin',
      password: 'admin-secret',
    );

    expect(requests, hasLength(2));
    expect(session.baseUrl, 'https://master.example.test');
    expect(session.tenantId, isNull);
    expect(session.scope, 'master_admin');
    expect(store.written?.accessToken, 'master-token');
  });

  test('login with multiple tenants surfaces a picker choice list', () async {
    final client = OdooApiClient(
      baseUrl: 'https://master.example.test',
      sessionStore: _MemorySessionStore(),
      httpClient: MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'error': 'multiple_tenants',
            'tenants': <Map<String, dynamic>>[
              <String, dynamic>{
                'tenant_id': 11,
                'name': 'Acme VN',
                'db': 'acme_vn',
                'base_url': 'https://acme.example.test/',
                'scope': 'full',
              },
              <String, dynamic>{
                'tenant_id': 22,
                'name': 'Acme SG',
                'db': 'acme_sg',
                'base_url': 'https://acme.sg.example.test/',
                'scope': 'full',
              },
            ],
          }),
          409,
        );
      }),
    );

    final captured = <MultipleTenantsFailure>[];
    try {
      await client.login(login: 'demo@example.com', password: 'secret');
    } on MultipleTenantsFailure catch (e) {
      captured.add(e);
    }

    expect(captured, hasLength(1));
    final tenants = captured.single.tenants;
    expect(tenants, hasLength(2));
    expect(tenants[0].tenantId, 11);
    expect(tenants[0].name, 'Acme VN');
    expect(tenants[0].db, 'acme_vn');
    expect(tenants[0].baseUrl, 'https://acme.example.test/');
    expect(tenants[0].scope, 'full');
    expect(tenants[1].tenantId, 22);
    expect(tenants[1].name, 'Acme SG');
    expect(tenants[1].baseUrl, 'https://acme.sg.example.test/');
  });

  test('login sends tenant_id when forcing a tenant', () async {
    final store = _MemorySessionStore();
    final requests = <http.Request>[];
    final client = OdooApiClient(
      baseUrl: 'https://master.example.test',
      sessionStore: store,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.toString() ==
            'https://master.example.test/api/v1/mobile/auth/login') {
          expect(jsonDecode(request.body), <String, dynamic>{
            'login': 'demo@example.com',
            'password': 'secret',
            'tenant_id': 42,
          });
          return http.Response(
            jsonEncode(<String, dynamic>{
              'access_token': 'tenant-token-2',
              'uid': 9,
              'db': 'acme_vn',
              'base_url': 'https://acme.example.test/',
              'tenant_id': 42,
              'scope': 'full',
              'login': 'demo@example.com',
              'expires_in': 604800,
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );

    final session = await client.login(
      login: 'demo@example.com',
      password: 'secret',
      tenantId: 42,
    );

    expect(requests, hasLength(1));
    expect(session.tenantId, 42);
    expect(session.baseUrl, 'https://acme.example.test');
    expect(store.written?.tenantId, 42);
  });
}

class _MemorySessionStore extends OdooSessionStore {
  OdooSession? written;

  @override
  Future<OdooSession?> read() async => written;

  @override
  Future<void> write(OdooSession session) async {
    written = session;
  }

  @override
  Future<void> clear() async {
    written = null;
  }
}

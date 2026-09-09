import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/core/api/odoo_session_store.dart';
import 'package:vcloud/core/error/failure.dart';
import 'package:vcloud/features/auth/data/db_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Security: Master Directory Lookup (lookupDb)', () {
    test('lookupDb chỉ gửi login lên Master để tra cứu DB theo đúng sơ đồ 4 bước của Sếp Tân', () async {
      final requests = <http.Request>[];
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _MemorySessionStore(),
        httpClient: MockClient((request) async {
          requests.add(request);
          expect(request.url.toString(), 'https://vuahethong.net/api/v1/auth/lookup-db');
          expect(request.method, 'POST');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          // [SƠ ĐỒ SẾP TÂN]: Body chỉ chứa 'login', TUYỆT ĐỐI KHÔNG chứa 'password'
          expect(body.containsKey('login'), isTrue);
          expect(body['login'], 'user@example.com');
          expect(body.containsKey('password'), isFalse);

          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'status': 'success',
              'count': 1,
              'databases': [
                {
                  'login': 'user@example.com',
                  'database_name': 'client_db_1',
                  'database_url': 'https://client1.vuahethong.com',
                  'project_id': 101,
                }
              ]
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await client.lookupDb('user@example.com');

      expect(requests, hasLength(1));
      expect(result, hasLength(1));
      expect(result.first['database_name'], 'client_db_1');
      expect(result.first['database_url'], 'https://client1.vuahethong.com');
    });

    test('lookupDb trả về danh sách rỗng khi tài khoản không tồn tại', () async {
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _MemorySessionStore(),
        httpClient: MockClient((_) async {
          return http.Response(jsonEncode({'result': []}), 200);
        }),
      );

      final rawList = await client.lookupDb('nonexistent@example.com');
      final dbs = rawList.map(DbInfo.fromJson).toList();

      expect(dbs, isEmpty);
    });

    test('lookupDb trả về nhiều DB khi trùng username/email', () async {
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _MemorySessionStore(),
        httpClient: MockClient((_) async {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'result': [
                {
                  'login': 'alex@example.com',
                  'database_name': 'acme_corp',
                  'database_url': 'https://acme.vuahethong.com',
                  'project_id': 1,
                },
                {
                  'login': 'alex@example.com',
                  'database_name': 'beta_corp',
                  'database_url': 'https://beta.vuahethong.com',
                  'project_id': 2,
                },
              ]
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final rawList = await client.lookupDb('alex@example.com');
      final dbs = rawList.map(DbInfo.fromJson).toList();

      expect(dbs, hasLength(2));
      expect(dbs[0].databaseName, 'acme_corp');
      expect(dbs[0].databaseUrl, 'https://acme.vuahethong.com');
      expect(dbs[1].databaseName, 'beta_corp');
      expect(dbs[1].databaseUrl, 'https://beta.vuahethong.com');
    });
  });

  group('2. Direct Client Authentication (authenticateOnClient)', () {
    test('authenticateOnClient gửi đúng format Odoo JSON-RPC trực tiếp tới Client DB URL', () async {
      final requests = <http.Request>[];
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _MemorySessionStore(),
        httpClient: MockClient((request) async {
          requests.add(request);

          if (request.url.path.contains('/web/session/authenticate')) {
            expect(request.url.toString(), 'https://client1.vuahethong.com/web/session/authenticate');
            expect(request.method, 'POST');

            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['jsonrpc'], '2.0');

            final params = body['params'] as Map<String, dynamic>;
            expect(params['db'], 'client_db_1');
            expect(params['login'], 'user@example.com');
            expect(params['password'], 'secret_password_123');

            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'jsonrpc': '2.0',
                'result': {
                  'uid': 42,
                  'partner_id': 99,
                  'name': 'Nguyen Van A',
                  'username': 'user@example.com',
                  'db': 'client_db_1',
                }
              })),
              200,
              headers: {
                'content-type': 'application/json; charset=utf-8',
                'set-cookie': 'session_id=sess_abc123xyz; Path=/; HttpOnly',
              },
            );
          }

          if (request.url.path.contains('/api/v1/mobile/auth/login')) {
            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'access_token': 'jwt_access_token_123',
                'refresh_token': 'jwt_refresh_token_123',
                'uid': 42,
                'partner_id': 99,
                'db': 'client_db_1',
                'login': 'user@example.com',
              })),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }

          return http.Response('{}', 200);
        }),
      );

      const dbInfo = DbInfo(
        login: 'user@example.com',
        databaseName: 'client_db_1',
        databaseUrl: 'https://client1.vuahethong.com',
      );

      final session = await client.authenticateOnClient(
        targetBaseUrl: dbInfo.databaseUrl,
        dbName: dbInfo.databaseName,
        login: 'user@example.com',
        password: 'secret_password_123',
      );

      expect(requests, hasLength(2));
      expect(session.uid, 42);
      expect(session.partnerId, 99);
      expect(session.db, 'client_db_1');
      expect(session.accessToken, 'jwt_access_token_123');
      expect(session.baseUrl, 'https://client1.vuahethong.com');
    });

    test('authenticateOnClient ném Failure khi mật khẩu không chính xác', () async {
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _MemorySessionStore(),
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'error': {
                'code': 200,
                'message': 'Odoo Server Error',
                'data': {
                  'name': 'odoo.exceptions.AccessDenied',
                  'message': 'Access Denied',
                }
              }
            }),
            200,
          );
        }),
      );

      const dbInfo = DbInfo(
        login: 'user@example.com',
        databaseName: 'client_db_1',
        databaseUrl: 'https://client1.vuahethong.com',
      );

      expect(
        () => client.authenticateOnClient(
          targetBaseUrl: dbInfo.databaseUrl,
          dbName: dbInfo.databaseName,
          login: 'user@example.com',
          password: 'wrong_password',
        ),
        throwsA(isA<Failure>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group 3: E2E trực tiếp qua OdooApiClient (không qua AuthRepository._toUser
  // vì FlutterSecureStorage không mock được trong pure Dart test)
  // ---------------------------------------------------------------------------
  group('3. End-to-End Workflow qua OdooApiClient', () {
    test('Luồng 1 DB: lookupDb -> 1 DB -> authenticateOnClient thành công, session được lưu', () async {
      final store = _MemorySessionStore();
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: store,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/api/v1/auth/lookup-db')) {
            // Verify: [SƠ ĐỒ SẾP TÂN] Chỉ gửi login lên Master, TUYỆT ĐỐI KHÔNG gửi password
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['login'], 'single@example.com');
            expect(body.containsKey('password'), isFalse);

            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'result': [
                  {
                    'login': 'single@example.com',
                    'database_name': 'single_db',
                    'database_url': 'https://single.vuahethong.com',
                  }
                ]
              })),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }

          if (request.url.host == 'single.vuahethong.com' &&
              request.url.path.contains('/web/session/authenticate')) {
            // Verify: password đi thẳng đến Client DB
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final params = body['params'] as Map<String, dynamic>;
            expect(params['password'], 'my_password');
            expect(params['db'], 'single_db');
            expect(request.url.host, 'single.vuahethong.com',
                reason: 'Password phải gửi đến Client DB, không phải Master');

            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'jsonrpc': '2.0',
                'result': {
                  'uid': 10,
                  'partner_id': 20,
                  'name': 'Single User',
                  'username': 'single@example.com',
                }
              })),
              200,
              headers: {
                'content-type': 'application/json; charset=utf-8',
                'set-cookie': 'session_id=sess_single_999; Path=/',
              },
            );
          }

          return http.Response('{}', 200);
        }),
      );

      // Bước 2: Lookup — chỉ gửi login lên Master
      final rawDbs = await client.lookupDb('single@example.com');
      expect(rawDbs, hasLength(1));

      final db = DbInfo.fromJson(rawDbs.first);
      expect(db.databaseName, 'single_db');
      expect(db.databaseUrl, 'https://single.vuahethong.com');

      // Bước 3b + 4: Xác thực trực tiếp vào Client DB URL
      final session = await client.authenticateOnClient(
        targetBaseUrl: db.databaseUrl,
        dbName: db.databaseName,
        login: 'single@example.com',
        password: 'my_password',
      );

      // Bước 5: Kiểm tra session được lưu đúng
      expect(session.uid, 10);
      expect(session.db, 'single_db');
      expect(session.baseUrl, 'https://single.vuahethong.com');
      expect(session.accessToken, 'sess_single_999');
      expect(store.written?.accessToken, 'sess_single_999',
          reason: 'Session phải được persist vào store');
    });

    test('Luồng 0 DB: lookupDb trả về rỗng, không gọi authenticate', () async {
      int authenticateCalls = 0;
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _MemorySessionStore(),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/web/session/authenticate')) {
            authenticateCalls++;
          }
          return http.Response(jsonEncode({'result': []}), 200);
        }),
      );

      final rawDbs = await client.lookupDb('ghost@example.com');
      expect(rawDbs, isEmpty);
      expect(authenticateCalls, 0,
          reason: 'Không được gọi authenticate khi không tìm thấy DB');
    });

    test('Luồng >1 DB: lookupDb trả về 2 DB, user phải chọn trước khi authenticate', () async {
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _MemorySessionStore(),
        httpClient: MockClient((_) async {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'result': [
                {'login': 'multi@ex.com', 'database_name': 'db_a', 'database_url': 'https://a.vuahethong.com'},
                {'login': 'multi@ex.com', 'database_name': 'db_b', 'database_url': 'https://b.vuahethong.com'},
              ]
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final rawDbs = await client.lookupDb('multi@ex.com');
      final dbs = rawDbs.map(DbInfo.fromJson).toList();

      expect(dbs, hasLength(2));
      expect(dbs[0].databaseName, 'db_a');
      expect(dbs[0].databaseUrl, 'https://a.vuahethong.com');
      expect(dbs[1].databaseName, 'db_b');
      expect(dbs[1].databaseUrl, 'https://b.vuahethong.com');

      // Giả lập user chọn DB thứ 2 — authenticate đến đúng URL đó
      final selectedDb = dbs[1];
      expect(selectedDb.databaseUrl, 'https://b.vuahethong.com');
    });
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

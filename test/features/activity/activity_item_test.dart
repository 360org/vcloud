import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/core/api/odoo_session_store.dart';
import 'package:vcloud/features/activity/data/models/activity_item.dart';
import 'package:vcloud/features/activity/data/models/activity_type.dart';
import 'package:vcloud/features/activity/data/repositories/activity_repository.dart';

class _MockActivityApiClient implements OdooApiClient {
  @override
  OdooSession? session;

  bool failRest = false;
  String? lastGetPath;
  String? lastPostPath;
  Map<String, dynamic>? lastPostBody;
  int ensureSessionCookieCallCount = 0;
  bool lastEnsureForceRefresh = false;

  @override
  Future<String?> ensureSessionCookie({bool forceRefresh = false}) async {
    ensureSessionCookieCallCount++;
    lastEnsureForceRefresh = forceRefresh;
    return 'mock_cookie_123';
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool auth = true,
    Duration? timeout,
  }) async {
    lastGetPath = path;
    if (failRest) {
      throw Exception('405 Method Not Allowed');
    }
    return [
      {
        'id': 101,
        'summary': 'Hoạt động REST',
        'date_deadline': '2026-11-04',
        'state': 'today',
      }
    ];
  }

  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool auth = true,
    Duration? timeout,
  }) async {
    lastPostPath = path;
    if (body is Map<String, dynamic>) {
      lastPostBody = body;
    }
    if (failRest && path.startsWith('/api/v1/mobile')) {
      throw Exception('405 Method Not Allowed');
    }

    if (path == '/web/dataset/call_kw/mail.activity/search_read') {
      return {
        'jsonrpc': '2.0',
        'result': [
          {
            'id': 202,
            'summary': 'Hoạt động Odoo ORM search_read',
            'date_deadline': '2026-11-04',
            'state': 'today',
            'user_id': [1, 'Admin'],
          }
        ]
      };
    }

    if (path == '/web/dataset/call_kw/mail.activity.type/search_read') {
      return {
        'jsonrpc': '2.0',
        'result': [
          {
            'id': 1,
            'name': 'Email',
            'summary': 'Gửi email',
          }
        ]
      };
    }

    return {'result': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ActivityItem Model Tests', () {
    test('parses full json correctly', () {
      final json = <String, dynamic>{
        'id': 42,
        'summary': '<p>Gọi điện trao đổi hợp đồng</p>',
        'note': '<b>Ghi chú</b>: Khách hàng cần báo giá gấp',
        'date_deadline': '2026-12-31T10:00:00Z',
        'state': 'planned',
        'activity_type_id': 1,
        'activity_type_name': 'Gọi điện',
        'res_model': 'helpdesk.ticket',
        'res_id': 105,
        'res_name': 'Ticket #105 - Sự cố mạng',
        'user_name': 'Nguyễn Văn A',
      };

      final item = ActivityItem.fromJson(json);

      expect(item.id, equals(42));
      expect(item.summary, equals('Gọi điện trao đổi hợp đồng'));
      expect(item.note, equals('Ghi chú: Khách hàng cần báo giá gấp'));
      expect(item.state, equals('planned'));
      expect(item.activityTypeId, equals(1));
      expect(item.activityTypeName, equals('Gọi điện'));
      expect(item.resModel, equals('helpdesk.ticket'));
      expect(item.resId, equals(105));
      expect(item.resName, equals('Ticket #105 - Sự cố mạng'));
      expect(item.userName, equals('Nguyễn Văn A'));
      expect(item.isPlanned, isTrue);
      expect(item.isOverdue, isFalse);
    });

    test('correctly identifies overdue state', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 2));
      final json = <String, dynamic>{
        'id': 1,
        'summary': 'Việc quá hạn',
        'note': '',
        'date_deadline': yesterday.toIso8601String(),
        'state': 'overdue',
      };

      final item = ActivityItem.fromJson(json);
      expect(item.isOverdue, isTrue);
      expect(item.isToday, isFalse);
    });

    test('correctly identifies today state', () {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day, 14, 0);
      final json = <String, dynamic>{
        'id': 2,
        'summary': 'Việc trong ngày',
        'note': '',
        'date_deadline': todayDate.toIso8601String(),
        'state': 'today',
      };

      final item = ActivityItem.fromJson(json);
      expect(item.isToday, isTrue);
      expect(item.isOverdue, isFalse);
    });

    test('parses Odoo tuple format for activity_type_id and user_id', () {
      final json = <String, dynamic>{
        'id': 10,
        'summary': 'Kiểm tra tuple',
        'note': '',
        'activity_type_id': [5, 'Email'],
        'user_id': [8, 'Trần Thị B'],
      };

      final item = ActivityItem.fromJson(json);
      expect(item.activityTypeId, equals(5));
      expect(item.activityTypeName, equals('Email'));
      expect(item.userName, equals('Trần Thị B'));
    });

    test('serializes to json properly', () {
      const item = ActivityItem(
        id: 99,
        summary: 'Demo Task',
        note: 'Some note',
        state: 'planned',
        activityTypeId: 2,
        activityTypeName: 'Email',
        resModel: 'project.task',
        resId: 200,
        resName: 'Task #200',
        userName: 'Admin',
      );

      final json = item.toJson();
      expect(json['id'], equals(99));
      expect(json['summary'], equals('Demo Task'));
      expect(json['note'], equals('Some note'));
      expect(json['state'], equals('planned'));
      expect(json['activity_type_id'], equals(2));
      expect(json['activity_type_name'], equals('Email'));
      expect(json['res_model'], equals('project.task'));
      expect(json['res_id'], equals(200));
      expect(json['res_name'], equals('Task #200'));
      expect(json['user_name'], equals('Admin'));
    });
  });

  group('ActivityType Model Tests', () {
    test('parses json correctly', () {
      final json = <String, dynamic>{
        'id': 3,
        'name': 'Gặp mặt',
        'summary': 'Gặp trực tiếp khách hàng',
        'icon': 'fa-users',
      };

      final type = ActivityType.fromJson(json);
      expect(type.id, equals(3));
      expect(type.name, equals('Gặp mặt'));
      expect(type.summary, equals('Gặp trực tiếp khách hàng'));
      expect(type.icon, equals('fa-users'));

      final map = type.toJson();
      expect(map['id'], equals(3));
      expect(map['name'], equals('Gặp mặt'));
    });
  });

  group('ActivityRepository Tests', () {
    test('can instantiate repository', () {
      final repo = ActivityRepository();
      expect(repo, isNotNull);
    });

    test('getActivities succeeds with REST API when available', () async {
      final mock = _MockActivityApiClient();
      final repo = ActivityRepository(mock);

      final items = await repo.getActivities();
      expect(items.length, 1);
      expect(items.first.id, 101);
      expect(items.first.summary, 'Hoạt động REST');
      expect(mock.lastGetPath, '/api/v1/mobile/activities');
    });

    test('getActivities falls back to Odoo Core ORM search_read on 405 error', () async {
      final mock = _MockActivityApiClient()..failRest = true;
      final repo = ActivityRepository(mock);

      final items = await repo.getActivities(filter: 'today');
      expect(items.length, 1);
      expect(items.first.id, 202);
      expect(items.first.summary, 'Hoạt động Odoo ORM search_read');
      expect(mock.lastPostPath, '/web/dataset/call_kw/mail.activity/search_read');
      expect(mock.lastPostBody?['params']?['model'], 'mail.activity');
      expect(mock.lastPostBody?['params']?['method'], 'search_read');
    });

    test('markDone falls back to action_feedback on REST failure', () async {
      final mock = _MockActivityApiClient()..failRest = true;
      final repo = ActivityRepository(mock);

      await repo.markDone(202, feedback: 'Đã hoàn thành tốt');
      expect(mock.lastPostPath, '/web/dataset/call_kw/mail.activity/action_feedback');
      expect(mock.lastPostBody?['params']?['model'], 'mail.activity');
      expect(mock.lastPostBody?['params']?['method'], 'action_feedback');
      expect(mock.lastPostBody?['params']?['args'], [[202]]);
      expect(mock.lastPostBody?['params']?['kwargs']?['feedback'], 'Đã hoàn thành tốt');
    });

    test('cancelActivity falls back to unlink on REST failure', () async {
      final mock = _MockActivityApiClient()..failRest = true;
      final repo = ActivityRepository(mock);

      await repo.cancelActivity(202);
      expect(mock.lastPostPath, '/web/dataset/call_kw/mail.activity/unlink');
      expect(mock.lastPostBody?['params']?['model'], 'mail.activity');
      expect(mock.lastPostBody?['params']?['method'], 'unlink');
      expect(mock.lastPostBody?['params']?['args'], [[202]]);
    });

    test('getActivityTypes falls back to mail.activity.type search_read on failure', () async {
      final mock = _MockActivityApiClient()..failRest = true;
      final repo = ActivityRepository(mock);

      final types = await repo.getActivityTypes();
      expect(types.length, 1);
      expect(types.first.id, 1);
      expect(types.first.name, 'Email');
      expect(mock.lastPostPath, '/web/dataset/call_kw/mail.activity.type/search_read');
    });

    test('getActivities calls ensureSessionCookie before calling ORM fallback', () async {
      final mock = _MockActivityApiClient()..failRest = true;
      final repo = ActivityRepository(mock);

      await repo.getActivities();
      expect(mock.ensureSessionCookieCallCount, greaterThanOrEqualTo(1));
    });

    test('getActivities automatically refreshes cookie and retries when ORM returns Session Expired', () async {
      final mock = _SessionExpiredRecoveryMockApiClient()..failRest = true;
      final repo = ActivityRepository(mock);

      final items = await repo.getActivities();
      expect(items.length, 1);
      expect(items.first.id, 999);
      expect(items.first.summary, 'Hoạt động sau khi tự động khôi phục session');
      expect(mock.ensureSessionCookieCallCount, 2); // 1 lần ban đầu + 1 lần forceRefresh
      expect(mock.lastEnsureForceRefresh, isTrue);
    });

    test('getActivities throws Failure when ORM returns persistent error', () async {
      // Simulate persistent ORM error
      final customMock = _ErrorMockActivityApiClient()..failRest = true;
      final repo = ActivityRepository(customMock);

      expect(() => repo.getActivities(), throwsA(isA<Exception>()));
    });
  });

  group('OdooSession Cookie & Persistence Tests', () {
    test('copyWith updates sessionId while preserving all other fields', () {
      final now = DateTime.now().toUtc();
      final session = OdooSession(
        accessToken: 'jwt_orig_token',
        uid: 10,
        db: 'vuahethong',
        login: 'tanmnn@360.org.vn',
        expiresAt: now.add(const Duration(days: 7)),
        baseUrl: 'https://vuahethong.net',
        sessionId: null,
      );

      final updated = session.copyWith(sessionId: 'new_session_id_456');
      expect(updated.sessionId, equals('new_session_id_456'));
      expect(updated.accessToken, equals('jwt_orig_token'));
      expect(updated.uid, equals(10));
      expect(updated.db, equals('vuahethong'));
      expect(updated.login, equals('tanmnn@360.org.vn'));
      expect(updated.baseUrl, equals('https://vuahethong.net'));
    });

    test('serializes and deserializes sessionId correctly', () {
      final now = DateTime.now().toUtc();
      final session = OdooSession(
        accessToken: 'jwt_token_123',
        uid: 2,
        db: 'vcloud_test_v19',
        login: 'admin',
        expiresAt: now.add(const Duration(days: 30)),
        baseUrl: 'http://192.168.1.100:1900',
        sessionId: 'sess_abc123xyz',
      );

      final json = session.toJson();
      expect(json['session_id'], equals('sess_abc123xyz'));

      final restored = OdooSession.fromJson(json);
      expect(restored.sessionId, equals('sess_abc123xyz'));
      expect(restored.accessToken, equals('jwt_token_123'));
      expect(restored.uid, equals(2));
      expect(restored.db, equals('vcloud_test_v19'));
    });
  });

  group('OdooApiClient ensureSessionCookie Unit Tests', () {
    test('extracts session_id from Set-Cookie header on HTTP 303 without following redirect', () async {
      final store = _TestMemorySessionStore();
      final now = DateTime.now().toUtc();
      store.stored = OdooSession(
        accessToken: 'valid_jwt_token',
        uid: 1,
        db: 'vuahethong',
        login: 'admin',
        expiresAt: now.add(const Duration(days: 7)),
        baseUrl: 'https://vuahethong.net',
      );

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: store,
        httpClient: MockClient((request) async {
          expect(request.url.path, equals('/api/v1/mobile/web/auth'));
          expect(request.url.queryParameters['token'], equals('valid_jwt_token'));
          expect(request.url.queryParameters['db'], equals('vuahethong'));
          expect(request.followRedirects, isFalse);

          return http.Response(
            '',
            303,
            headers: {
              'location': '/web?db=vuahethong&session_id=sid_cookie_from_set_cookie_999',
              'set-cookie': 'session_id=sid_cookie_from_set_cookie_999; Path=/; HttpOnly',
            },
          );
        }),
      );

      await client.restoreSession();
      final sid = await client.ensureSessionCookie();

      expect(sid, equals('sid_cookie_from_set_cookie_999'));
      expect(client.session?.sessionId, equals('sid_cookie_from_set_cookie_999'));
      expect(store.stored?.sessionId, equals('sid_cookie_from_set_cookie_999'));
    });

    test('extracts session_id from Location redirect header when set-cookie is missing', () async {
      final store = _TestMemorySessionStore();
      final now = DateTime.now().toUtc();
      store.stored = OdooSession(
        accessToken: 'valid_jwt_token_2',
        uid: 2,
        db: 'vcloud_test_v19',
        login: 'demo',
        expiresAt: now.add(const Duration(days: 7)),
        baseUrl: 'http://192.168.1.100:1900',
      );

      final client = OdooApiClient(
        baseUrl: 'http://192.168.1.100:1900',
        sessionStore: store,
        httpClient: MockClient((request) async {
          return http.Response(
            '',
            303,
            headers: {
              'location': '/web?db=vcloud_test_v19&session_id=sid_from_location_header_888',
            },
          );
        }),
      );

      await client.restoreSession();
      final sid = await client.ensureSessionCookie();

      expect(sid, equals('sid_from_location_header_888'));
      expect(client.session?.sessionId, equals('sid_from_location_header_888'));
    });

    test('reuses existing session_id if forceRefresh is false', () async {
      final store = _TestMemorySessionStore();
      final now = DateTime.now().toUtc();
      store.stored = OdooSession(
        accessToken: 'jwt_token',
        uid: 1,
        db: 'vuahethong',
        login: 'admin',
        expiresAt: now.add(const Duration(days: 7)),
        baseUrl: 'https://vuahethong.net',
        sessionId: 'existing_valid_sid_777',
      );

      var httpCallCount = 0;
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: store,
        httpClient: MockClient((request) async {
          httpCallCount++;
          return http.Response('', 200);
        }),
      );

      await client.restoreSession();
      final sid = await client.ensureSessionCookie(forceRefresh: false);

      expect(sid, equals('existing_valid_sid_777'));
      expect(httpCallCount, equals(0)); // Không gọi mạng vì đã có cookie
    });

    test('refreshes session_id when forceRefresh is true', () async {
      final store = _TestMemorySessionStore();
      final now = DateTime.now().toUtc();
      store.stored = OdooSession(
        accessToken: 'jwt_token',
        uid: 1,
        db: 'vuahethong',
        login: 'admin',
        expiresAt: now.add(const Duration(days: 7)),
        baseUrl: 'https://vuahethong.net',
        sessionId: 'old_expired_sid',
      );

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: store,
        httpClient: MockClient((request) async {
          return http.Response(
            '',
            303,
            headers: {
              'set-cookie': 'session_id=brand_new_refreshed_sid_555; Path=/; HttpOnly',
            },
          );
        }),
      );

      await client.restoreSession();
      final sid = await client.ensureSessionCookie(forceRefresh: true);

      expect(sid, equals('brand_new_refreshed_sid_555'));
      expect(client.session?.sessionId, equals('brand_new_refreshed_sid_555'));
    });
  });
}

class _TestMemorySessionStore implements OdooSessionStore {
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

class _ErrorMockActivityApiClient extends _MockActivityApiClient {
  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool auth = true,
    Duration? timeout,
  }) async {
    lastPostPath = path;
    return {
      'jsonrpc': '2.0',
      'error': {
        'code': 100,
        'message': 'Odoo Session Expired',
        'data': {'name': 'odoo.http.SessionExpiredException'},
      },
    };
  }
}

class _SessionExpiredRecoveryMockApiClient extends _MockActivityApiClient {
  int postCallCount = 0;

  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool auth = true,
    Duration? timeout,
  }) async {
    lastPostPath = path;
    postCallCount++;

    // Lần 1 ném lỗi Session Expired
    if (postCallCount == 1) {
      return {
        'jsonrpc': '2.0',
        'error': {
          'code': 100,
          'message': 'Odoo Session Expired',
          'data': {'name': 'odoo.http.SessionExpiredException'},
        },
      };
    }

    // Lần 2 (sau khi tự động cấp mới cookie) trả về danh sách thành công
    return {
      'jsonrpc': '2.0',
      'result': [
        {
          'id': 999,
          'summary': 'Hoạt động sau khi tự động khôi phục session',
          'date_deadline': '2026-11-04',
          'state': 'today',
          'user_id': [1, 'Admin'],
        }
      ],
    };
  }
}

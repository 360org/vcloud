import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/notifications/push_notification_repository.dart';

void main() {
  test(
    'registerDevice posts current FCM token metadata to mobile endpoint',
    () async {
      final client = _FakeOdooApiClient(<String, dynamic>{
        'status': 'registered',
        'device_id': 12,
      });
      final repo = PushNotificationRepository(client: client);

      final result = await repo.registerDevice(
        deviceToken: 'fcm-token',
        platform: 'android',
        deviceName: 'Pixel 8',
        installationId: 'install-uuid',
        appVersion: '1.0.0+1',
      );

      expect(result.status, 'registered');
      expect(result.deviceId, 12);
      expect(client.lastPostPath, '/api/v1/mobile/notifications/register');
      expect(client.lastPostBody, <String, dynamic>{
        'device_token': 'fcm-token',
        'platform': 'android',
        'installation_id': 'install-uuid',
        'device_name': 'Pixel 8',
        'app_version': '1.0.0+1',
      });
    },
  );

  test(
    'unregisterDevice posts only the FCM token to mobile endpoint',
    () async {
      final client = _FakeOdooApiClient(<String, dynamic>{
        'status': 'unregistered',
      });
      final repo = PushNotificationRepository(client: client);

      await repo.unregisterDevice(deviceToken: 'fcm-token');

      expect(client.lastPostPath, '/api/v1/mobile/notifications/unregister');
      expect(client.lastPostBody, <String, dynamic>{
        'device_token': 'fcm-token',
      });
    },
  );

  test(
    'listNotifications maps NotificationListResponse into items + totals',
    () async {
      final client = _FakeOdooApiClient(
        const <String, dynamic>{},
        getResponses: [
          <String, dynamic>{
            'items': <Map<String, dynamic>>[
              {
                'id': 7,
                'event_type': 'ticket_assigned',
                'title': 'Ticket mới',
                'body': 'Bạn được gán ticket #42',
                'data': <String, dynamic>{'ticket_id': 42},
                'status': 'sent',
                'sent_at': '2026-07-06T08:00:00Z',
              },
              {
                'id': 8,
                'event_type': 'message',
                'title': 'Tin nhắn mới',
                'body': 'Xin chào',
                'data': <String, dynamic>{'channel_id': 5},
                'status': 'pending',
                'create_date': '2026-07-06T08:01:00',
              },
            ],
            'total': 2,
            'limit': 50,
            'offset': 0,
            'has_more': false,
          },
        ],
      );
      final repo = PushNotificationRepository(client: client);

      final list = await repo.listNotifications();

      expect(client.lastGetPath, '/api/v1/mobile/notifications/list');
      expect(list.items.length, 2);
      expect(list.total, 2);
      expect(list.hasMore, false);
      expect(list.items[0].eventType, 'ticket_assigned');
      expect(list.items[0].title, 'Ticket mới');
      expect(list.items[0].data['ticket_id'], 42);
      expect(list.items[0].timestamp?.toUtc(), DateTime.utc(2026, 7, 6, 8, 0));
      expect(list.items[1].eventType, 'message');
      expect(list.items[1].status, 'pending');
    },
  );

  test(
    'watchNotifications emits on listen and re-polls on the interval',
    () async {
      // Each GET returns a list whose total grows by one per call, so the
      // second emission proves the timer fired.
      final client = _FakeOdooApiClient(
        const <String, dynamic>{},
        getResponses: [
          <String, dynamic>{
            'items': <Map<String, dynamic>>[],
            'total': 1,
            'limit': 50,
            'offset': 0,
            'has_more': false,
          },
          <String, dynamic>{
            'items': <Map<String, dynamic>>[
              {
                'id': 1,
                'event_type': 'message',
                'title': 'Hi',
                'body': '',
                'data': <String, dynamic>{},
                'status': 'sent',
              },
            ],
            'total': 2,
            'limit': 50,
            'offset': 0,
            'has_more': false,
          },
        ],
      );
      final repo = PushNotificationRepository(client: client);

      final stream = repo.watchNotifications(
        pollInterval: const Duration(milliseconds: 60),
      );

      final emissions = <int>[];
      final sub = stream.listen((list) => emissions.add(list.total));

      // Wait long enough for the initial emit + at least one tick.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await sub.cancel();

      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.first, 1);
      expect(emissions.last, 2);
    },
  );
}

class _FakeOdooApiClient extends OdooApiClient {
  _FakeOdooApiClient(
    this._postResponse, {
    List<Map<String, dynamic>>? getResponses,
  }) : _getResponses = getResponses ?? const <Map<String, dynamic>>[],
       super(baseUrl: 'https://example.test');

  final Object _postResponse;
  final List<Map<String, dynamic>> _getResponses;
  int _getCalls = 0;
  String? lastGetPath;
  Map<String, Object?>? lastGetQuery;
  String? lastPostPath;
  Object? lastPostBody;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    lastGetPath = path;
    lastGetQuery = query;
    // Return successive responses; hold the last one once exhausted so a
    // long-running stream never throws out of bounds.
    final index = _getCalls < _getResponses.length ? _getCalls : _getResponses.length - 1;
    _getCalls++;
    return _getResponses[index];
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    lastPostPath = path;
    lastPostBody = body;
    return _postResponse;
  }
}

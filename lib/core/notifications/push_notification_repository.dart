import 'dart:async';

import '../api/odoo_api_client.dart';
import '../error/failure.dart';
import 'realtime_constants.dart';

class MobileNotificationList {
  const MobileNotificationList({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<MobileNotificationItem> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  factory MobileNotificationList.fromMap(Map<String, dynamic> map) {
    return MobileNotificationList(
      items: (map['items'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => MobileNotificationItem.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      total: _intOrZero(map['total']),
      limit: _intOrZero(map['limit']),
      offset: _intOrZero(map['offset']),
      hasMore: map['has_more'] == true,
    );
  }
}

class MobileNotificationItem {
  const MobileNotificationItem({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    required this.data,
    required this.status,
    this.providerMessageId,
    this.errorMessage,
    this.sentAt,
    this.createdAt,
  });

  final int id;
  final String eventType;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String status;
  final String? providerMessageId;
  final String? errorMessage;
  final DateTime? sentAt;
  final DateTime? createdAt;

  DateTime? get timestamp => sentAt ?? createdAt;

  factory MobileNotificationItem.fromMap(Map<String, dynamic> map) {
    return MobileNotificationItem(
      id: _intOrZero(map['id']),
      eventType: (map['event_type'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      data: map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : const <String, dynamic>{},
      status: (map['status'] ?? '').toString(),
      providerMessageId: _stringOrNull(map['provider_message_id']),
      errorMessage: _stringOrNull(map['error_message']),
      sentAt: _dateTimeOrNull(map['sent_at']),
      createdAt: _dateTimeOrNull(map['create_date']),
    );
  }
}

class PushDeviceRegistration {
  const PushDeviceRegistration({required this.status, required this.deviceId});

  final String status;
  final int deviceId;

  factory PushDeviceRegistration.fromMap(Map<String, dynamic> map) {
    return PushDeviceRegistration(
      status: (map['status'] ?? '').toString(),
      deviceId: _intOrZero(map['device_id']),
    );
  }

}

class PushNotificationRepository {
  PushNotificationRepository({OdooApiClient? client})
    : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  Future<MobileNotificationList> listNotifications({
    int limit = 50,
    int offset = 0,
    String status = '',
    String eventType = '',
  }) async {
    final response = await _client.get(
      '/api/v1/mobile/notifications/list',
      query: <String, Object?>{
        'limit': limit,
        'offset': offset,
        'status': status,
        'event_type': eventType,
      },
    );
    if (response is! Map) {
      throw Failure('Phản hồi danh sách thông báo không hợp lệ.');
    }
    return MobileNotificationList.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  /// Live notification feed for the bell. Emits the current list on listen,
  /// then re-polls on [pollInterval] (defaults to
  /// [RealtimeIntervals.notifications]) until the subscription cancels —
  /// at which point the timer is stopped and the controller closed.
  ///
  /// The `refresh()` closure is the single data-entry seam: a future
  /// websocket can replace the [Timer.periodic] with a push subscription
  /// that calls it, without changing anything downstream.
  Stream<MobileNotificationList> watchNotifications({
    int limit = 50,
    int offset = 0,
    String status = '',
    String eventType = '',
    Duration pollInterval = RealtimeIntervals.notifications,
  }) {
    final controller = StreamController<MobileNotificationList>();
    bool inFlight = false;
    Timer? timer;

    Future<void> refresh() async {
      if (inFlight || controller.isClosed) return;
      inFlight = true;
      try {
        final list = await listNotifications(
          limit: limit,
          offset: offset,
          status: status,
          eventType: eventType,
        );
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      } finally {
        inFlight = false;
      }
    }

    controller.onListen = () {
      refresh();
      void scheduleNextPoll() {
        if (controller.isClosed) return;
        timer?.cancel();
        timer = Timer(pollInterval, () async {
          if (!controller.isClosed) {
            await refresh();
            scheduleNextPoll();
          }
        });
      }
      scheduleNextPoll();
    };
    controller.onCancel = () {
      timer?.cancel();
      timer = null;
    };
    return controller.stream;
  }

  Future<PushDeviceRegistration> registerDevice({
    required String deviceToken,
    required String platform,
    required String installationId,
    String? deviceName,
    String? appVersion,
  }) async {
    if (deviceToken.isEmpty) {
      throw Failure('Thiếu mã thiết bị thông báo.');
    }

    final response = await _client.post(
      '/api/v1/mobile/notifications/register',
      body: <String, dynamic>{
        'device_token': deviceToken,
        'platform': platform,
        'installation_id': installationId,
        if (deviceName != null && deviceName.isNotEmpty)
          'device_name': deviceName,
        if (appVersion != null && appVersion.isNotEmpty)
          'app_version': appVersion,
      },
    );
    if (response is! Map) {
      throw Failure('Phản hồi đăng ký thông báo không hợp lệ.');
    }
    return PushDeviceRegistration.fromMap(Map<String, dynamic>.from(response));
  }

  Future<void> unregisterDevice({required String deviceToken}) async {
    if (deviceToken.isEmpty) return;
    await _client.post(
      '/api/v1/mobile/notifications/unregister',
      body: <String, dynamic>{'device_token': deviceToken},
    );
  }
}

int _intOrZero(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _stringOrNull(Object? value) {
  if (value == null || value == false) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

DateTime? _dateTimeOrNull(Object? value) {
  final text = _stringOrNull(value);
  if (text == null) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null || parsed.isUtc || _hasTimezone(text)) return parsed;
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

bool _hasTimezone(String value) {
  return RegExp(
    r'(z|[+-]\d\d:?\d\d)$',
    caseSensitive: false,
  ).hasMatch(value.trim());
}

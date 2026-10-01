import 'dart:async';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/error/failure.dart';
import '../../../shared/models/activity_log.dart';

class ActivityLogRepository {
  ActivityLogRepository({OdooApiClient? client})
    : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  Stream<List<ActivityLog>> watchByTicket(String ticketId) {
    final ctl = StreamController<List<ActivityLog>>();

    Future<void> refresh() async {
      try {
        final res = await _client.get(
          '/api/v1/mobile/ticket/$ticketId/activities',
        );
        final rows = res is Map
            ? (res['activities'] ?? res['data'] ?? const <dynamic>[])
            : res;
        final activities = (rows as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((m) => _activityFromMobile(ticketId, m))
            .toList();
        if (!ctl.isClosed) {
          ctl.add(activities);
        }
      } catch (e) {
        if (!ctl.isClosed) {
          ctl.addError(Failure('Load activity log failed: $e'));
        }
      }
    }

    ctl.onListen = refresh;
    return ctl.stream;
  }

  Future<void> log({
    required String? ticketId,
    required String action,
    Map<String, dynamic>? details,
  }) async {
    if (ticketId == null || ticketId.isEmpty) return;
    try {
      await _client.post(
        '/api/v1/mobile/ticket/$ticketId/activities',
        body: <String, dynamic>{
          'summary': action,
          if (details != null && details['note'] != null) 'note': details['note'],
          if (details != null && details['activity_type_id'] != null)
            'activity_type_id': details['activity_type_id'],
          if (details != null && details['date_deadline'] != null)
            'date_deadline': details['date_deadline'],
          if (details != null && details['user_id'] != null)
            'user_id': details['user_id'],
        },
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw Failure('Không thể tạo hoạt động: $e');
    }
  }

  Future<void> markDone(int activityId, {String? feedback}) async {
    try {
      await _client.post(
        '/api/v1/mobile/ticket/activities/$activityId/done',
        body: <String, dynamic>{
          if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
        },
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw Failure('Không thể hoàn thành hoạt động: $e');
    }
  }

  Future<List<Map<String, dynamic>>> activityTypes() async {
    try {
      final res = await _client.get('/api/v1/mobile/ticket/activity-types');
      if (res is List) {
        return res.cast<Map<String, dynamic>>();
      }
      return const <Map<String, dynamic>>[];
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  ActivityLog _activityFromMobile(String ticketId, Map<dynamic, dynamic> map) {
    final createdAt =
        map['created_at'] ??
        map['create_date'] ??
        map['date'] ??
        DateTime.now().toIso8601String();
    return ActivityLog.fromMap(<String, dynamic>{
      'id': (map['id'] ?? '${ticketId}_$createdAt').toString(),
      'ticket_id': ticketId,
      'user_id': _recordId(map['user_id'] ?? map['author_id']),
      'action': (map['action'] ?? map['type'] ?? map['summary'] ?? 'updated')
          .toString(),
      'details': <String, dynamic>{
        if (map['summary'] != null) 'summary': map['summary'],
        if (map['note'] != null) 'note': map['note'],
        if (map['preview'] != null) 'preview': map['preview'],
      },
      'created_at': createdAt.toString(),
    });
  }

  String? _recordId(Object? value) {
    if (value == null || value == false) return null;
    if (value is List && value.isNotEmpty) return value.first.toString();
    if (value is Map && value['id'] != null) return value['id'].toString();
    return value.toString();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/error/failure.dart';
import '../../../auth/application/auth_controller.dart';
import '../models/activity_item.dart';
import '../models/activity_type.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(odooApiClient);
});

/// Provider tính toán tổng số việc cần làm (quá hạn + hôm nay)
/// để hiển thị trên badge đồng hồ màn hình chính (HomeScreen).
final pendingActivitiesCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null || user.isPortal) return 0;

  final repo = ref.watch(activityRepositoryProvider);
  try {
    final overdueFuture = repo.getActivities(filter: 'overdue');
    final todayFuture = repo.getActivities(filter: 'today');
    final results = await Future.wait([overdueFuture, todayFuture]);
    return results[0].length + results[1].length;
  } catch (e) {
    debugPrint('[pendingActivitiesCountProvider] Error fetching activities count: $e');
    return 0;
  }
});

/// Provider lấy tối đa 3 việc cần làm (ưu tiên quá hạn, sau đó đến hôm nay)
/// để hiển thị trên widget _PendingActivitiesSection màn hình chính (HomeScreen).
final homeActivitiesPreviewProvider =
    FutureProvider.autoDispose<List<ActivityItem>>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null || user.isPortal) return const <ActivityItem>[];

  final repo = ref.watch(activityRepositoryProvider);
  try {
    final overdueFuture = repo.getActivities(filter: 'overdue');
    final todayFuture = repo.getActivities(filter: 'today');
    final results = await Future.wait([overdueFuture, todayFuture]);
    final overdue = results[0];
    final today = results[1];

    final seenIds = <int>{};
    final merged = <ActivityItem>[];
    for (final item in [...overdue, ...today]) {
      if (seenIds.add(item.id)) {
        merged.add(item);
      }
    }

    merged.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      final dateA = a.dateDeadline ?? DateTime(2099);
      final dateB = b.dateDeadline ?? DateTime(2099);
      return dateA.compareTo(dateB);
    });

    return merged.take(3).toList();
  } catch (e) {
    debugPrint('[homeActivitiesPreviewProvider] Error fetching activities preview: $e');
    return const <ActivityItem>[];
  }
});

class ActivityRepository {
  ActivityRepository([OdooApiClient? client])
      : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  /// Lấy danh sách hoạt động từ API (tự động fallback sang Odoo Core ORM search_read nếu endpoint REST chưa deploy)
  /// [filter]: 'all', 'overdue', 'today', 'planned'
  /// [typeId]: lọc theo loại hoạt động cụ thể
  Future<List<ActivityItem>> getActivities({
    String filter = 'all',
    int? typeId,
  }) async {
    // 1. Thử gọi REST API /api/v1/mobile/activities
    try {
      final query = <String, Object?>{};
      if (filter.isNotEmpty && filter != 'all') {
        query['filter'] = filter;
      }
      if (typeId != null) {
        query['type_id'] = typeId;
      }

      final res = await _client.get('/api/v1/mobile/activities', query: query);
      List<dynamic> rows = const <dynamic>[];
      if (res is List) {
        rows = res;
      } else if (res is Map) {
        final data = res['data'] ?? res['activities'] ?? res['result'];
        if (data is List) {
          rows = data;
        }
      }
      return rows
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => ActivityItem.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('[ActivityRepository.getActivities] REST failed ($e), falling back to Odoo ORM search_read');

      // 2. Fallback sang Odoo Core ORM call_kw search_read trên mail.activity
      try {
        await _client.ensureSessionCookie();

        final domain = <dynamic>[];
        final now = DateTime.now();
        final todayStr =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        // Lọc theo người dùng hiện tại
        final uid = _client.session?.uid;
        if (uid != null && uid > 0) {
          domain.add(['user_id', '=', uid]);
        }

        if (filter == 'overdue') {
          domain.add(['date_deadline', '<', todayStr]);
        } else if (filter == 'today') {
          domain.add(['date_deadline', '=', todayStr]);
        } else if (filter == 'planned' || filter == 'upcoming') {
          domain.add(['date_deadline', '>', todayStr]);
        }

        if (typeId != null) {
          domain.add(['activity_type_id', '=', typeId]);
        }

        Map<String, dynamic> buildCallKwPayload() => {
              'jsonrpc': '2.0',
              'method': 'call',
              'params': {
                'model': 'mail.activity',
                'method': 'search_read',
                'args': [domain],
                'kwargs': {
                  'fields': [
                    'id',
                    'summary',
                    'note',
                    'activity_type_id',
                    'date_deadline',
                    'state',
                    'user_id',
                    'res_model',
                    'res_id',
                    'res_name',
                    'create_uid',
                    'create_date',
                  ],
                  'limit': 80,
                  'order': 'date_deadline asc, id desc',
                },
              },
            };

        dynamic rpcRes = await _client.post(
          '/web/dataset/call_kw/mail.activity/search_read',
          body: buildCallKwPayload(),
          auth: true,
        );

        List<dynamic> rows = const <dynamic>[];
        if (rpcRes is Map) {
          if (rpcRes['error'] != null) {
            final errorMap = rpcRes['error'];
            final msg = errorMap is Map
                ? (errorMap['message'] ?? errorMap['data']?['message'] ?? 'ORM Error')
                : errorMap.toString();
            debugPrint('🚨 [ActivityRepository.getActivities] ORM error: $msg');

            // Tự động khôi phục cookie và thử lại nếu phiên Odoo hết hạn
            if (msg.contains('Session Expired') ||
                msg.contains('SessionExpiredException') ||
                msg.contains('Session Invalid')) {
              debugPrint('🔄 [ActivityRepository] Session hết hạn, tự động làm mới session_id và thử lại...');
              final refreshedSid = await _client.ensureSessionCookie(forceRefresh: true);
              if (refreshedSid != null && refreshedSid.isNotEmpty) {
                rpcRes = await _client.post(
                  '/web/dataset/call_kw/mail.activity/search_read',
                  body: buildCallKwPayload(),
                  auth: true,
                );
              }
            }

            if (rpcRes is Map && rpcRes['error'] != null) {
              final finalErrMap = rpcRes['error'];
              final finalMsg = finalErrMap is Map
                  ? (finalErrMap['message'] ?? finalErrMap['data']?['message'] ?? 'ORM Error')
                  : finalErrMap.toString();
              throw Failure('Lỗi tải hoạt động từ Odoo: $finalMsg');
            }
          }
          final result = rpcRes['result'];
          if (result is List) {
            rows = result;
          }
        }
        return rows
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => ActivityItem.fromJson(m.cast<String, dynamic>()))
            .toList();
      } catch (err) {
        debugPrint('[ActivityRepository.getActivities] ORM search_read fallback failed: $err');
        if (err is Failure) rethrow;
        throw Failure('Không thể tải danh sách hoạt động: $err');
      }
    }
  }

  /// Đánh dấu hoàn tất một hoạt động
  Future<void> markDone(int id, {String? feedback}) async {
    try {
      await _client.post(
        '/api/v1/mobile/activities/$id/done',
        body: <String, dynamic>{
          if (feedback != null && feedback.trim().isNotEmpty)
            'feedback': feedback.trim(),
        },
      );
    } catch (_) {
      try {
        await _client.ensureSessionCookie();
        await _client.post(
          '/web/dataset/call_kw/mail.activity/action_feedback',
          body: {
            'jsonrpc': '2.0',
            'method': 'call',
            'params': {
              'model': 'mail.activity',
              'method': 'action_feedback',
              'args': [
                [id]
              ],
              'kwargs': {
                if (feedback != null && feedback.trim().isNotEmpty)
                  'feedback': feedback.trim(),
              },
            },
          },
          auth: true,
        );
      } catch (e) {
        if (e is Failure) rethrow;
        throw Failure('Không thể hoàn tất hoạt động: $e');
      }
    }
  }

  /// Hủy một hoạt động
  Future<void> cancelActivity(int id) async {
    try {
      await _client.post('/api/v1/mobile/activities/$id/unlink');
    } catch (_) {
      try {
        await _client.ensureSessionCookie();
        await _client.post(
          '/web/dataset/call_kw/mail.activity/unlink',
          body: {
            'jsonrpc': '2.0',
            'method': 'call',
            'params': {
              'model': 'mail.activity',
              'method': 'unlink',
              'args': [
                [id]
              ],
              'kwargs': {},
            },
          },
          auth: true,
        );
      } catch (e) {
        if (e is Failure) rethrow;
        throw Failure('Không thể hủy hoạt động: $e');
      }
    }
  }

  /// Lấy danh sách các loại hoạt động
  Future<List<ActivityType>> getActivityTypes() async {
    try {
      final res = await _client.get('/api/v1/mobile/activity-types');
      List<dynamic> rows = const <dynamic>[];
      if (res is List) {
        rows = res;
      } else if (res is Map) {
        final data = res['data'] ?? res['activity_types'] ?? res['result'];
        if (data is List) {
          rows = data;
        }
      }
      return rows
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => ActivityType.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      try {
        await _client.ensureSessionCookie();
        final dynamic rpcRes = await _client.post(
          '/web/dataset/call_kw/mail.activity.type/search_read',
          body: {
            'jsonrpc': '2.0',
            'method': 'call',
            'params': {
              'model': 'mail.activity.type',
              'method': 'search_read',
              'args': [[]],
              'kwargs': {
                'fields': ['id', 'name', 'summary', 'icon'],
                'order': 'sequence asc, id asc',
              },
            },
          },
          auth: true,
        );
        List<dynamic> rows = const <dynamic>[];
        if (rpcRes is Map) {
          if (rpcRes['error'] != null) {
            debugPrint('🚨 [ActivityRepository.getActivityTypes] ORM error: ${rpcRes['error']}');
          } else if (rpcRes['result'] is List) {
            rows = rpcRes['result'] as List;
          }
        }
        return rows
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => ActivityType.fromJson(m.cast<String, dynamic>()))
            .toList();
      } catch (_) {
        return const <ActivityType>[];
      }
    }
  }
}

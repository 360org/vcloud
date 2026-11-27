import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/attendance/domain/shift_calculator.dart';
import '../../features/chat_v2/data/models/chat_v2_channel.dart';
import '../../shared/models/attendance.dart';
import '../router/app_router.dart';

/// Notification IDs dành riêng cho Nhắc nhở chấm công
const int kAttendanceCheckInReminderNotifId = 8001;
const int kAttendanceCheckOutReminderNotifId = 8002;

/// Service quản lý thông báo cục bộ nhắc nhở Check-in và Check-out
class AttendanceLocalReminderService {
  AttendanceLocalReminderService._();
  @visibleForTesting
  AttendanceLocalReminderService.test();
  static AttendanceLocalReminderService instance =
      AttendanceLocalReminderService._();

  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  FlutterLocalNotificationsPlugin get _plugin =>
      _notificationsPlugin ??= FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get _isUnitTest =>
      !kIsWeb &&
      const bool.fromEnvironment('dart.vm.product') == false &&
      kDebugMode &&
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Khởi tạo local notification plugin và timezone
  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    try {
      tz.initializeTimeZones();
      final currentTimeZone = DateTime.now().timeZoneName;
      try {
        tz.setLocalLocation(tz.getLocation(currentTimeZone));
      } catch (_) {
        // Fallback sang GMT/UTC+7 nếu timezone name không chuẩn định dạng IANA
        tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      }
    } catch (e) {
      debugPrint('[AttendanceReminder] Timezone init fallback: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      // Trong môi trường Unit Test, không gọi plugin native để tránh lỗi Platform Interface
      if (!_isUnitTest) {
        await _plugin.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );
      }
      _initialized = true;
      debugPrint('[AttendanceReminder] Local Notifications initialized successfully.');
    } catch (e) {
      debugPrint('[AttendanceReminder] Initialize error: $e');
    }
  }

  /// Callback khi người dùng click vào thông báo trên thanh trạng thái / màn hình khóa
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('[AttendanceReminder] User tapped notification: payload=$payload');
    handlePayload(payload);
  }

  /// Xử lý điều hướng khi bấm vào thông báo (dùng chung cho cả Local Notification & Push Notification)
  static void handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final context = rootNavigatorKey.currentContext;
      if (context == null) return;

      if (payload.startsWith('{')) {
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final resId = data['res_id'] ?? data['channel_id'] ?? data['discuss_channel_id'] ?? data['chat_id'];
          final model = (data['model'] ?? data['type'] ?? '').toString().toLowerCase();
          final resModel = (data['res_model'] ?? '').toString().toLowerCase();
          final ticketId = data['ticket_id'] ?? data['helpdesk_ticket_id'];
          final eventType = (data['event_type'] ?? '').toString().toLowerCase();
          final action = (data['action'] ?? '').toString().toLowerCase();

          if (eventType.contains('attendance') || action == 'checkin' || action == 'checkout') {
            if (action == 'checkout') {
              GoRouter.of(context).go('/attendance?action=checkout');
            } else {
              GoRouter.of(context).go('/attendance');
            }
          } else if (model.contains('helpdesk') ||
              model.contains('ticket') ||
              data.containsKey('ticket_id') ||
              data.containsKey('helpdesk_ticket_id') ||
              (model == 'mail.message' && resModel.contains('helpdesk'))) {
            final targetTicketId = ticketId ?? resId;
            if (targetTicketId != null &&
                targetTicketId.toString().isNotEmpty &&
                targetTicketId.toString() != '0') {
              GoRouter.of(context).go('/tickets/$targetTicketId');
            } else {
              GoRouter.of(context).go('/tickets');
            }
          } else if (model.contains('task') ||
              model.contains('timesheet') ||
              data.containsKey('task_id') ||
              (model == 'mail.message' && resModel.contains('task'))) {
            final targetTaskId = data['task_id'] ?? resId;
            if (targetTaskId != null && targetTaskId.toString().isNotEmpty && targetTaskId.toString() != '0') {
              GoRouter.of(context).go('/timesheet?task_id=$targetTaskId');
            } else {
              GoRouter.of(context).go('/timesheet');
            }
          } else if ((model.contains('discuss') || model.contains('chat')) &&
              resId != null &&
              resId.toString().isNotEmpty &&
              resId.toString() != '0') {
            final rawChannelName = data['channel_name'] ?? data['name'] ?? '';
            final cleanChannelName = ChatV2Channel.cleanChannelName(rawChannelName.toString());
            GoRouter.of(context).go(
              '/chat/$resId?name=${Uri.encodeComponent(cleanChannelName)}',
            );
          } else {
            GoRouter.of(context).go('/');
          }
          return;
        } catch (e) {
          debugPrint('[AttendanceReminder] Error handling json payload: $e');
        }
      }

      if (payload == 'checkin') {
        GoRouter.of(context).go('/attendance');
      } else if (payload == 'checkout') {
        GoRouter.of(context).go('/attendance?action=checkout');
      }
    } catch (e) {
      debugPrint('[AttendanceReminder] Error handling payload: $e');
    }
  }

  /// Yêu cầu cấp quyền thông báo trên Android 13+ và iOS
  Future<bool> requestPermissions() async {
    if (kIsWeb || _isUnitTest) return true;

    if (!_initialized) await initialize();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidPlugin?.requestNotificationsPermission();
        return granted ?? true;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosPlugin = _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      }
    } catch (e) {
      debugPrint('[AttendanceReminder] Request permission error: $e');
    }
    return true;
  }

  /// Kiểm tra xem thời điểm hiện tại đã quá giờ hết hạn nhắc nhở check-in ca sáng (sau 12:00 hoặc giờ nghỉ trưa) hay chưa.
  static bool isPastMorningCheckInCutoff({
    required DateTime currentTime,
    ShiftConfig? shiftConfig,
  }) {
    final cfg = shiftConfig ?? ShiftConfig.forDate(currentTime);
    final cutoffHour = cfg.lunchStartHour > 0 ? cfg.lunchStartHour : 12;
    final cutoffMinute = cfg.lunchStartMinute;
    if (currentTime.hour > cutoffHour) return true;
    if (currentTime.hour == cutoffHour && currentTime.minute >= cutoffMinute) return true;
    return false;
  }

  /// Kiểm tra xem thời điểm hiện tại đã quá giờ hết hạn nhắc nhở check-out ca chiều (mặc định sau 22:00 đêm) hay chưa.
  static bool isPastAfternoonCheckOutCutoff({
    required DateTime currentTime,
    int cutoffHour = 22,
    int cutoffMinute = 0,
  }) {
    if (currentTime.hour > cutoffHour) return true;
    if (currentTime.hour == cutoffHour && currentTime.minute >= cutoffMinute) return true;
    return false;
  }

  /// Server Cron FCM (`_cron_attendance_reminder_checkin` / `_checkout`) là
  /// Single Source of Truth duy nhất cho nhắc nhở chấm công.
  /// Phương thức này chỉ dọn sạch báo thức cục bộ cũ (ID 8001/8002) để tránh nổ đúp.
  Future<void> syncAttendanceReminders({
    required Attendance? openAttendance,
    required List<Attendance> todayAttendances,
    ShiftConfig? shiftConfig,
  }) async {
    if (kIsWeb || _isUnitTest) return;
    await cancelAllAttendanceReminders();
    return;
  }

  /// Hủy thông báo nhắc Check-in
  Future<void> cancelCheckInReminder() async {
    if (kIsWeb || _isUnitTest) return;

    try {
      await _plugin.cancel(id: kAttendanceCheckInReminderNotifId);
      debugPrint('[AttendanceReminder] Cancelled Check-in reminder.');
    } catch (e) {
      debugPrint('[AttendanceReminder] Error cancelling checkin reminder: $e');
    }
  }

  /// Hủy thông báo nhắc Check-out
  Future<void> cancelCheckOutReminder() async {
    if (kIsWeb || _isUnitTest) return;

    try {
      await _plugin.cancel(id: kAttendanceCheckOutReminderNotifId);
      debugPrint('[AttendanceReminder] Cancelled Check-out reminder.');
    } catch (e) {
      debugPrint('[AttendanceReminder] Error cancelling checkout reminder: $e');
    }
  }

  /// Hủy toàn bộ thông báo nhắc chấm công
  Future<void> cancelAllAttendanceReminders() async {
    await cancelCheckInReminder();
    await cancelCheckOutReminder();
  }
}

/// Provider toàn cục để theo dõi và đồng bộ nhắc nhở chấm công
final attendanceReminderServiceProvider =
    Provider<AttendanceLocalReminderService>((ref) {
  return AttendanceLocalReminderService.instance;
});

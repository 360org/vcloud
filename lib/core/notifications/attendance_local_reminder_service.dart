import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/attendance/domain/shift_calculator.dart';
import '../../shared/models/attendance.dart';
import '../router/app_router.dart';

/// Notification IDs dành riêng cho Nhắc nhở chấm công
const int kAttendanceCheckInReminderNotifId = 8001;
const int kAttendanceCheckOutReminderNotifId = 8002;

/// Service quản lý thông báo cục bộ nhắc nhở Check-in và Check-out
class AttendanceLocalReminderService {
  AttendanceLocalReminderService._();
  static final AttendanceLocalReminderService instance =
      AttendanceLocalReminderService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Khởi tạo local notification plugin và timezone
  Future<void> initialize() async {
    if (_initialized) return;

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
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
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
    if (!_initialized) await initialize();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidPlugin?.requestNotificationsPermission();
        return granted ?? true;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosPlugin = _notificationsPlugin
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

  /// Cập nhật trạng thái nhắc nhở dựa trên bản ghi Chấm công hiện tại
  /// - Nếu chưa check-in sáng nay: Lên lịch nhắc Check-in lúc 08:05
  /// - Nếu đã check-in nhưng chưa check-out: Hủy nhắc check-in & Lên lịch nhắc Check-out lúc 17:35
  /// - Nếu đã hoàn tất cả check-in và check-out: Hủy toàn bộ nhắc nhở hôm nay
  Future<void> syncAttendanceReminders({
    required Attendance? openAttendance,
    required List<Attendance> todayAttendances,
    ShiftConfig? shiftConfig,
  }) async {
    if (!_initialized) await initialize();

    final now = DateTime.now();
    // Không nhắc nhở vào Chủ Nhật
    if (now.weekday == DateTime.sunday) {
      await cancelAllAttendanceReminders();
      return;
    }

    final cfg = shiftConfig ?? ShiftConfig.forDate(now);
    final hasCheckedInToday = todayAttendances.any((a) => a.checkinTime != null);
    final isOpen = openAttendance != null && openAttendance.checkoutTime == null;

    if (!hasCheckedInToday) {
      // 1. Chưa check-in hôm nay -> Lên lịch nhắc Check-in
      await _scheduleCheckInReminder(
        targetHour: cfg.shiftStartHour,
        targetMinute: cfg.shiftStartMinute + 5, // Trễ 5 phút sau ca bắt đầu
      );
      await cancelCheckOutReminder();
    } else if (isOpen) {
      // 2. Đã check-in và đang mở ca -> Hủy nhắc check-in, lên lịch nhắc Check-out
      await cancelCheckInReminder();

      // Giờ tan ca quy định hoặc sau 8 tiếng làm việc
      await _scheduleCheckOutReminder(
        targetHour: cfg.shiftEndHour,
        targetMinute: cfg.shiftEndMinute + 5, // 5 phút sau ca kết thúc
      );
    } else {
      // 3. Đã check-in và đã check-out đủ các ca -> Hủy toàn bộ nhắc nhở
      await cancelAllAttendanceReminders();
    }
  }

  /// Lên lịch nhắc Check-in buổi sáng
  Future<void> _scheduleCheckInReminder({
    required int targetHour,
    required int targetMinute,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        targetHour,
        targetMinute,
      );

      // Nếu đã qua giờ nhắc hôm nay thì bỏ qua
      if (now.isAfter(scheduledDate)) {
        await cancelCheckInReminder();
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'attendance_reminders_channel',
        'Nhắc nhở Chấm công',
        channelDescription: 'Thông báo nhắc nhở Check-in và Check-out hàng ngày',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id: kAttendanceCheckInReminderNotifId,
        title: '⏰ Sếp ơi, chưa Check-in chấm công!',
        body: 'Đã qua giờ vào ca làm việc rồi. Bấm vào đây để Check-in ngay nhé!',
        scheduledDate: scheduledDate,
        notificationDetails: notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'checkin',
      );

      debugPrint(
        '[AttendanceReminder] Scheduled Check-in reminder at '
        '${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      debugPrint('[AttendanceReminder] Error scheduling checkin reminder: $e');
    }
  }

  /// Lên lịch nhắc Check-out buổi chiều
  Future<void> _scheduleCheckOutReminder({
    required int targetHour,
    required int targetMinute,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        targetHour,
        targetMinute,
      );

      // Nếu đã qua giờ nhắc hôm nay thì bỏ qua
      if (now.isAfter(scheduledDate)) {
        await cancelCheckOutReminder();
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'attendance_reminders_channel',
        'Nhắc nhở Chấm công',
        channelDescription: 'Thông báo nhắc nhở Check-in và Check-out hàng ngày',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id: kAttendanceCheckOutReminderNotifId,
        title: '🏢 Hết giờ làm việc rồi Sếp ơi!',
        body: 'Đã hết ca làm việc. Đừng quên bấm Check-out trước khi về nhé!',
        scheduledDate: scheduledDate,
        notificationDetails: notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'checkout',
      );

      debugPrint(
        '[AttendanceReminder] Scheduled Check-out reminder at '
        '${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      debugPrint('[AttendanceReminder] Error scheduling checkout reminder: $e');
    }
  }

  /// Hủy thông báo nhắc Check-in
  Future<void> cancelCheckInReminder() async {
    try {
      await _notificationsPlugin.cancel(id: kAttendanceCheckInReminderNotifId);
      debugPrint('[AttendanceReminder] Cancelled Check-in reminder.');
    } catch (e) {
      debugPrint('[AttendanceReminder] Error cancelling checkin reminder: $e');
    }
  }

  /// Hủy thông báo nhắc Check-out
  Future<void> cancelCheckOutReminder() async {
    try {
      await _notificationsPlugin.cancel(id: kAttendanceCheckOutReminderNotifId);
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

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

  /// Cập nhật trạng thái nhắc nhở dựa trên bản ghi Chấm công hiện tại
  /// - Nếu chưa check-in sáng nay: Lên lịch nhắc Check-in lúc 08:05 (hủy nếu quá 12:00 trưa)
  /// - Nếu đã check-in nhưng chưa check-out: Hủy nhắc check-in & Lên lịch nhắc Check-out lúc 17:35 (hủy nếu quá 22:00 đêm)
  /// - Nếu đã hoàn tất cả check-in và check-out: Hủy toàn bộ nhắc nhở hôm nay
  Future<void> syncAttendanceReminders({
    required Attendance? openAttendance,
    required List<Attendance> todayAttendances,
    ShiftConfig? shiftConfig,
  }) async {
    if (kIsWeb || _isUnitTest) return;

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
      // 1. Chưa check-in hôm nay
      // Kiểm tra giờ hết hạn ca sáng: Nếu thời điểm kích hoạt/đồng bộ đã quá buổi trưa (sau 12:00 hoặc giờ nghỉ trưa)
      // thì tự động hủy bỏ nhắc nhở check-in, tránh tình trạng Android hoãn báo thức rồi xả nhầm vào ban đêm.
      if (isPastMorningCheckInCutoff(currentTime: now, shiftConfig: cfg)) {
        debugPrint('[AttendanceReminder] Past morning shift cutoff (>= 12:00/lunch). Canceling checkin reminder.');
        await cancelCheckInReminder();
      } else {
        await _scheduleCheckInReminder(
          targetHour: cfg.shiftStartHour,
          targetMinute: cfg.shiftStartMinute + 5, // Trễ 5 phút sau ca bắt đầu
          expireHour: cfg.lunchStartHour > 0 ? cfg.lunchStartHour : 12,
          expireMinute: cfg.lunchStartMinute,
        );
      }
      await cancelCheckOutReminder();
    } else if (isOpen) {
      // 2. Đã check-in và đang mở ca -> Hủy nhắc check-in
      await cancelCheckInReminder();

      // Nếu đã quá 22:00 đêm thì không lập lịch nhắc check-out nữa, tránh nổ lúc nửa đêm
      if (isPastAfternoonCheckOutCutoff(currentTime: now)) {
        debugPrint('[AttendanceReminder] Past 22:00 night cutoff. Canceling checkout reminder.');
        await cancelCheckOutReminder();
      } else {
        await _scheduleCheckOutReminder(
          targetHour: cfg.shiftEndHour,
          targetMinute: cfg.shiftEndMinute + 5, // 5 phút sau ca kết thúc
        );
      }
    } else {
      // 3. Đã check-in và đã check-out đủ các ca -> Hủy toàn bộ nhắc nhở
      await cancelAllAttendanceReminders();
    }
  }

  /// Lên lịch nhắc Check-in buổi sáng (có cơ chế tự hủy khi quá giờ trưa 12:00)
  Future<void> _scheduleCheckInReminder({
    required int targetHour,
    required int targetMinute,
    int expireHour = 12,
    int expireMinute = 0,
  }) async {
    if (kIsWeb || _isUnitTest) return;

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

      final expireDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        expireHour,
        expireMinute,
      );

      // Nếu đã qua giờ nhắc hoặc đã quá giờ hết hạn ca sáng (sau 12:00) thì hủy và bỏ qua
      if (now.isAfter(scheduledDate) || now.isAfter(expireDate) || now.isAtSameMomentAs(expireDate)) {
        await cancelCheckInReminder();
        return;
      }

      // Giới hạn thời gian notification tồn tại trên Android qua timeoutAfter:
      // Tính từ lúc scheduledDate đến lúc hết ca sáng (12:00), Android tự hủy nếu bị hoãn quá thời hạn này
      final timeoutDuration = expireDate.difference(scheduledDate);
      final timeoutMs = timeoutDuration.inMilliseconds > 0
          ? timeoutDuration.inMilliseconds
          : 14400000; // fallback 4 giờ

      final androidDetails = AndroidNotificationDetails(
        'attendance_reminders_channel',
        'Nhắc nhở Chấm công',
        channelDescription: 'Thông báo nhắc nhở Check-in và Check-out hàng ngày',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        timeoutAfter: timeoutMs,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Thêm cơ chế kiểm tra quyền và tự động fallback trong lập lịch báo thức chấm công
      var scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      if (defaultTargetPlatform == TargetPlatform.android && !_isUnitTest) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final canScheduleExact = await androidPlugin?.canScheduleExactNotifications();
        if (canScheduleExact == false) {
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
          debugPrint('[AttendanceReminder] Android exact alarm permission not granted. Falling back to inexactAllowWhileIdle.');
        }
      }

      await _plugin.zonedSchedule(
        id: kAttendanceCheckInReminderNotifId,
        title: '⏰ Sếp ơi, chưa Check-in chấm công!',
        body: 'Đã qua giờ vào ca làm việc rồi. Bấm vào đây để Check-in ngay nhé!',
        scheduledDate: scheduledDate,
        notificationDetails: notifDetails,
        androidScheduleMode: scheduleMode,
        payload: 'checkin',
      );

      debugPrint(
        '[AttendanceReminder] Scheduled Check-in reminder at '
        '${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}, '
        'cutoff at ${expireDate.hour}:${expireDate.minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      debugPrint('[AttendanceReminder] Error scheduling checkin reminder: $e');
    }
  }

  /// Lên lịch nhắc Check-out buổi chiều (có cơ chế tự hủy khi quá 22:00 đêm)
  Future<void> _scheduleCheckOutReminder({
    required int targetHour,
    required int targetMinute,
    int expireHour = 22,
    int expireMinute = 0,
  }) async {
    if (kIsWeb || _isUnitTest) return;

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

      final expireDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        expireHour,
        expireMinute,
      );

      // Nếu đã qua giờ nhắc hoặc đã qua 22:00 đêm thì bỏ qua
      if (now.isAfter(scheduledDate) || now.isAfter(expireDate) || now.isAtSameMomentAs(expireDate)) {
        await cancelCheckOutReminder();
        return;
      }

      // Giới hạn thời gian notification tồn tại trên Android qua timeoutAfter:
      // Tính từ lúc scheduledDate đến lúc 22:00 đêm
      final timeoutDuration = expireDate.difference(scheduledDate);
      final timeoutMs = timeoutDuration.inMilliseconds > 0
          ? timeoutDuration.inMilliseconds
          : 18000000; // fallback 5 giờ

      final androidDetails = AndroidNotificationDetails(
        'attendance_reminders_channel',
        'Nhắc nhở Chấm công',
        channelDescription: 'Thông báo nhắc nhở Check-in và Check-out hàng ngày',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        timeoutAfter: timeoutMs,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Thêm cơ chế kiểm tra quyền và tự động fallback trong lập lịch báo thức chấm công
      var scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      if (defaultTargetPlatform == TargetPlatform.android && !_isUnitTest) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final canScheduleExact = await androidPlugin?.canScheduleExactNotifications();
        if (canScheduleExact == false) {
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
          debugPrint('[AttendanceReminder] Android exact alarm permission not granted. Falling back to inexactAllowWhileIdle.');
        }
      }

      await _plugin.zonedSchedule(
        id: kAttendanceCheckOutReminderNotifId,
        title: '🏢 Hết giờ làm việc rồi Sếp ơi!',
        body: 'Đã hết ca làm việc. Đừng quên bấm Check-out trước khi về nhé!',
        scheduledDate: scheduledDate,
        notificationDetails: notifDetails,
        androidScheduleMode: scheduleMode,
        payload: 'checkout',
      );

      debugPrint(
        '[AttendanceReminder] Scheduled Check-out reminder at '
        '${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}, '
        'cutoff at ${expireDate.hour}:${expireDate.minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      debugPrint('[AttendanceReminder] Error scheduling checkout reminder: $e');
    }
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

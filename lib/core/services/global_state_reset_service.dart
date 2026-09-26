import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/attendance/data/attendance_repository.dart';
import '../../features/chat_v2/application/chat_v2_callkit_service.dart';
import '../../features/chat_v2/application/chat_v2_channels_controller.dart';
import '../../features/chat_v2/application/chat_v2_messages_controller.dart';
import '../../features/chat_v2/application/chat_v2_read_state_controller.dart';
import '../../features/chat_v2/data/chat_v2_repository.dart';
import '../../features/chat_v2/data/odoo_bus_service.dart';
import '../../features/chat_v2/presentation/widgets/chat_v2_message_item.dart';
import '../../features/home/application/home_summary_controller.dart';
import '../../features/ticket/application/ticket_controller.dart';
import '../../features/ticket/data/ticket_repository.dart';
import '../../features/timesheet/application/task_controller.dart';
import '../../features/timesheet/application/timesheet_controller.dart';
import '../../features/timesheet/data/task_repository.dart';
import '../../features/timesheet/data/timesheet_repository.dart';
import '../api/odoo_api_client.dart';
import '../notifications/attendance_local_reminder_service.dart';
import '../notifications/push_notification_controller.dart';
import '../utils/local_attachment_cache.dart';

/// Dịch vụ dọn dẹp và reset toàn diện trạng thái ứng dụng khi người dùng Logout
/// hoặc chuyển đổi tài khoản (Protocol V2.1: Session & State Leakage Protection).
class GlobalStateResetService {
  GlobalStateResetService._();

  /// Thực thi dọn dẹp tập trung 4 phân lớp dữ liệu:
  /// 1. In-Memory Cache (RAM): Xóa toàn bộ static list/map trong các Repositories & UI Widgets.
  /// 2. Disk & Local Storage: Xóa thư mục tin nhắn offline, attachments local cache, dismissed notifications.
  /// 3. State Management Reset (Riverpod): Reset các StateNotifier, invalidate providers keepAlive/dashboard/stream.
  /// 4. Background Services & Peripherals: Dập CallKit, ngắt Bus WebSocket, hủy nhắc nhở chấm công, xóa mapping API.
  static Future<void> clearAllUserDataOnLogout({
    Ref? ref,
    ProviderContainer? container,
  }) async {
    debugPrint('🧹 [GlobalStateResetService] Starting complete user data wipe across 4 layers...');

    // -------------------------------------------------------------------------
    // Phân lớp 1: In-Memory Cache (RAM) Wipe
    // -------------------------------------------------------------------------
    try {
      // 1.1 Ticket Repository (Root cause chính gây rò rỉ Ticket)
      TicketRepository.clearCache();

      // 1.2 Timesheet & Task Repositories
      TaskRepository.clearCache();
      TimesheetRepository.clearCache();

      // 1.3 Attendance Repository
      AttendanceRepository.clearCache();

      // 1.4 Chat V2 Repositories & Memory Caches
      ChatV2Repository.clearCache();
      ChatV2ReadStateNotifier.clearMemoryCache();
      ChatV2AttachmentImage.clearImageCache();

      // 1.5 Image Memory Cache của Flutter Engine
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}

      debugPrint('✅ [GlobalStateResetService] Layer 1 (In-Memory RAM) wiped.');
    } catch (e, st) {
      debugPrint('⚠️ [GlobalStateResetService] Layer 1 wipe error: $e\n$st');
    }

    // -------------------------------------------------------------------------
    // Phân lớp 2: Disk & Local Storage Wipe
    // -------------------------------------------------------------------------
    try {
      // 2.1 Xóa danh sách kênh chat cache & unread dưới secure storage / local
      ChatV2ChannelLocalCache.clear();

      // 2.2 Xóa tin nhắn chat offline dưới disk
      ChatV2MessageLocalCache.clear();

      // 2.3 Xóa toàn bộ file đính kèm lưu tạm (RAM + Disk/Web localStorage)
      await LocalAttachmentCache.clearAllCache();

      debugPrint('✅ [GlobalStateResetService] Layer 2 (Disk & Local Storage) wiped.');
    } catch (e, st) {
      debugPrint('⚠️ [GlobalStateResetService] Layer 2 wipe error: $e\n$st');
    }

    // -------------------------------------------------------------------------
    // Phân lớp 3: State Management (Riverpod) Reset
    // -------------------------------------------------------------------------
    try {
      // 3.1 Reset Ticket State
      resetTicketState(ref: ref, container: container);

      // 3.2 Reset Task State
      resetTaskState(ref: ref, container: container);

      // 3.3 Invalidate KeepAlive Dashboard & Summary
      if (ref != null) {
        ref.invalidate(mobileDashboardSummaryProvider);
        ref.invalidate(homeSummaryProvider);
        ref.invalidate(chatV2ChannelsProvider);
        try {
          ref.read(timesheetTimerControllerProvider.notifier).reset();
        } catch (_) {}
        try {
          await ref.read(dismissedNotificationIdsProvider.notifier).clearAllDismissed();
        } catch (_) {}
      } else if (container != null) {
        container.invalidate(mobileDashboardSummaryProvider);
        container.invalidate(homeSummaryProvider);
        container.invalidate(chatV2ChannelsProvider);
        try {
          container.read(timesheetTimerControllerProvider.notifier).reset();
        } catch (_) {}
        try {
          await container.read(dismissedNotificationIdsProvider.notifier).clearAllDismissed();
        } catch (_) {}
      }

      debugPrint('✅ [GlobalStateResetService] Layer 3 (State Management) reset.');
    } catch (e, st) {
      debugPrint('⚠️ [GlobalStateResetService] Layer 3 reset error: $e\n$st');
    }

    // -------------------------------------------------------------------------
    // Phân lớp 4: Peripheral & Background Services Isolation
    // -------------------------------------------------------------------------
    try {
      // 4.1 Xóa mapping partner/user trong OdooApiClient
      odooApiClient.clearPartnerToUserMap();

      // 4.2 Hủy thông báo nhắc nhở chấm công nội bộ
      try {
        await AttendanceLocalReminderService.instance.cancelAllAttendanceReminders();
      } catch (_) {}

      // 4.3 Dập tất cả cuộc gọi CallKit đang mở
      try {
        await ChatV2CallKitService.instance.endAllCalls();
      } catch (_) {}

      // 4.4 Ngắt kết nối Odoo Bus WebSocket nếu đang chạy
      if (ref != null) {
        try {
          ref.read(odooBusServiceProvider).disconnect();
        } catch (_) {}
      } else if (container != null) {
        try {
          container.read(odooBusServiceProvider).disconnect();
        } catch (_) {}
      }

      debugPrint('✅ [GlobalStateResetService] Layer 4 (Peripherals & Services) isolated.');
    } catch (e, st) {
      debugPrint('⚠️ [GlobalStateResetService] Layer 4 isolate error: $e\n$st');
    }

    debugPrint('🎉 [GlobalStateResetService] Global User Data Wipe Completed successfully.');
  }
}

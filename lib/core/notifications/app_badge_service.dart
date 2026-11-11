import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

import '../../features/chat_v2/application/chat_v2_channels_controller.dart';
import '../../features/chat_v2/application/chat_v2_inbox_controller.dart';

/// Provider tổng hợp số lượng cần hiển thị trên Launcher Icon Badge:
/// Bao gồm:
/// 1. Số lượng hội thoại/kênh chat có tin chưa đọc (chatV2TotalUnreadProvider)
/// 2. Số lượng thông báo Odoo Mailbox cần xử lý (inboxState.inboxTotal)
final appIconBadgeCountProvider = Provider<int>((ref) {
  final chatUnread = ref.watch(chatV2TotalUnreadProvider);
  final inboxTotal = ref.watch(
    chatV2InboxControllerProvider.select((s) => s.inboxTotal),
  );
  final safeChat = chatUnread < 0 ? 0 : chatUnread;
  final safeInbox = inboxTotal < 0 ? 0 : inboxTotal;
  return safeChat + safeInbox;
});

/// Provider tự động kích hoạt đồng bộ Badge ra Launcher Icon mỗi khi số lượng thay đổi.
/// Đặt `ref.watch(appBadgeSyncProvider)` tại gốc VCloudApp.build để tự động chạy nền.
final appBadgeSyncProvider = Provider<void>((ref) {
  final count = ref.watch(appIconBadgeCountProvider);
  AppBadgeService.instance.updateBadge(count);
});

/// Service quản lý hiển thị số lượng thông báo (Badge count) trên Launcher App Icon (iOS & Android).
/// Hoạt động tương tự như Zalo, Messenger, Telegram.
class AppBadgeService {
  AppBadgeService._();
  static final AppBadgeService instance = AppBadgeService._();

  int _currentBadge = -1;
  bool? _isSupported;

  /// Kiểm tra thiết bị / launcher có hỗ trợ hiển thị Badge hay không.
  Future<bool> isSupported() async {
    if (kIsWeb) return false;
    if (_isSupported != null) return _isSupported!;
    try {
      _isSupported = await AppBadgePlus.isSupported();
    } catch (e) {
      debugPrint('⚠️ [AppBadgeService] isSupported error: $e');
      _isSupported = false;
    }
    return _isSupported ?? false;
  }

  /// Cập nhật số đếm hiển thị trên App Icon.
  /// Nếu [count] <= 0: Tự động xóa badge về 0 (không hiển thị số).
  Future<void> updateBadge(int count) async {
    if (kIsWeb) return;
    final normalized = count < 0 ? 0 : count;

    // Tránh spam platform channel nếu số đếm không đổi
    if (_currentBadge == normalized) return;

    try {
      final supported = await isSupported();
      if (!supported) return;

      _currentBadge = normalized;
      await AppBadgePlus.updateBadge(normalized);
      debugPrint('🔔 [AppBadgeService] Đã cập nhật Badge icon: $normalized');
    } catch (e) {
      debugPrint('⚠️ [AppBadgeService] updateBadge($normalized) error: $e');
    }
  }

  /// Xóa sạch Badge trên Icon về 0 (Ví dụ khi người dùng đăng xuất).
  Future<void> clearBadge() async {
    await updateBadge(0);
  }

  /// Reset trạng thái bộ nhớ đệm (dùng cho unit test).
  @visibleForTesting
  void resetStateForTest() {
    _currentBadge = -1;
    _isSupported = null;
  }
}

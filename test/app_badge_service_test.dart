import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vcloud/core/notifications/app_badge_service.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_inbox_controller.dart';

class MockInboxController extends ChatV2InboxController {
  final int initialTotal;
  MockInboxController(this.initialTotal);

  @override
  ChatV2InboxState build() {
    return ChatV2InboxState(inboxTotal: initialTotal);
  }

  void setInboxTotal(int total) {
    state = state.copyWith(inboxTotal: total);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppBadgeService.instance.resetStateForTest();
  });

  group('Kiểm thử 10 case độc lập: AppBadgeService & appIconBadgeCountProvider', () {
    test('1. appIconBadgeCountProvider tính đúng tổng khi cả chat và inbox đều bằng 0', () {
      final container = ProviderContainer(
        overrides: [
          chatV2TotalUnreadProvider.overrideWithValue(0),
          chatV2InboxControllerProvider.overrideWith(() => MockInboxController(0)),
        ],
      );
      addTearDown(container.dispose);

      final total = container.read(appIconBadgeCountProvider);
      expect(total, equals(0));
    });

    test('2. appIconBadgeCountProvider tính đúng khi chỉ có tin nhắn chat chưa đọc', () {
      final container = ProviderContainer(
        overrides: [
          chatV2TotalUnreadProvider.overrideWithValue(7),
          chatV2InboxControllerProvider.overrideWith(() => MockInboxController(0)),
        ],
      );
      addTearDown(container.dispose);

      final total = container.read(appIconBadgeCountProvider);
      expect(total, equals(7));
    });

    test('3. appIconBadgeCountProvider tính đúng khi chỉ có thông báo Odoo inbox cần xử lý', () {
      final container = ProviderContainer(
        overrides: [
          chatV2TotalUnreadProvider.overrideWithValue(0),
          chatV2InboxControllerProvider.overrideWith(() => MockInboxController(12)),
        ],
      );
      addTearDown(container.dispose);

      final total = container.read(appIconBadgeCountProvider);
      expect(total, equals(12));
    });

    test('4. appIconBadgeCountProvider tính đúng tổng kết hợp (Chat + Odoo Mailbox)', () {
      final container = ProviderContainer(
        overrides: [
          chatV2TotalUnreadProvider.overrideWithValue(16),
          chatV2InboxControllerProvider.overrideWith(() => MockInboxController(50)),
        ],
      );
      addTearDown(container.dispose);

      final total = container.read(appIconBadgeCountProvider);
      expect(total, equals(66));
    });

    test('5. appIconBadgeCountProvider an toàn khi unread bị số âm (clamp về 0)', () {
      final container = ProviderContainer(
        overrides: [
          chatV2TotalUnreadProvider.overrideWithValue(-5),
          chatV2InboxControllerProvider.overrideWith(() => MockInboxController(-2)),
        ],
      );
      addTearDown(container.dispose);

      final total = container.read(appIconBadgeCountProvider);
      expect(total, equals(0));
    });

    test('6. appIconBadgeCountProvider phản ứng thời gian thực khi inboxTotal thay đổi', () {
      final inboxMock = MockInboxController(3);
      final container = ProviderContainer(
        overrides: [
          chatV2TotalUnreadProvider.overrideWithValue(4),
          chatV2InboxControllerProvider.overrideWith(() => inboxMock),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(appIconBadgeCountProvider), equals(7));

      // Đánh dấu xong một số tin
      inboxMock.setInboxTotal(1);
      expect(container.read(appIconBadgeCountProvider), equals(5));

      // Đánh dấu tất cả xong
      inboxMock.setInboxTotal(0);
      expect(container.read(appIconBadgeCountProvider), equals(4));
    });

    test('7. AppBadgeService.isSupported trả về boolean hợp lệ không ném exception', () async {
      final supported = await AppBadgeService.instance.isSupported();
      expect(supported, isA<bool>());
    });

    test('8. AppBadgeService.updateBadge thực thi an toàn với số âm và số 0', () async {
      await expectLater(AppBadgeService.instance.updateBadge(-10), completes);
      await expectLater(AppBadgeService.instance.updateBadge(0), completes);
    });

    test('9. AppBadgeService.clearBadge thực thi an toàn', () async {
      await expectLater(AppBadgeService.instance.clearBadge(), completes);
    });

    test('10. appBadgeSyncProvider kích hoạt đồng bộ khi được watch trong container', () {
      final container = ProviderContainer(
        overrides: [
          chatV2TotalUnreadProvider.overrideWithValue(8),
          chatV2InboxControllerProvider.overrideWith(() => MockInboxController(2)),
        ],
      );
      addTearDown(container.dispose);

      // Kích hoạt sync provider
      container.read(appBadgeSyncProvider);
      expect(container.read(appIconBadgeCountProvider), equals(10));
    });
  });
}

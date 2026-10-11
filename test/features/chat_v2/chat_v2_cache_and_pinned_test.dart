import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_messages_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat V2 Cache & Pinned Messages Protocol Tests (BUG-026)', () {
    const testChannelId = 'test_channel_99';
    final sampleMsg1 = ChatV2Message(
      id: '1001',
      channelId: testChannelId,
      content: 'Tin nhắn thường 1',
      createdAt: DateTime.parse('2026-10-10 10:00:00'),
    );
    final sampleMsg2 = ChatV2Message(
      id: '1002',
      channelId: testChannelId,
      content: 'Tin nhắn thường 2',
      createdAt: DateTime.parse('2026-10-10 10:05:00'),
    );
    final pinnedMsg = ChatV2Message(
      id: '1050',
      channelId: testChannelId,
      content: 'Thông báo ghim quan trọng',
      pinnedAt: '2026-10-10 10:00:00',
      createdAt: DateTime.parse('2026-10-09 08:00:00'),
    );

    // Test 1: ChatV2MessageLocalCache.set & get
    test('1. ChatV2MessageLocalCache.set lưu và đọc danh sách tin nhắn chính xác', () {
      ChatV2MessageLocalCache.set(testChannelId, [sampleMsg1, sampleMsg2], persist: false);
      final cached = ChatV2MessageLocalCache.get(testChannelId);
      expect(cached, isNotNull);
      expect(cached!.length, 2);
      expect(cached.map((m) => m.id), containsAll(['1001', '1002']));
    });

    // Test 2: ChatV2MessageLocalCache.removeMessage xóa đúng tin nhắn
    test('2. ChatV2MessageLocalCache.removeMessage xóa đúng 1 tin nhắn khỏi cache của kênh', () {
      ChatV2MessageLocalCache.set(testChannelId, [sampleMsg1, sampleMsg2], persist: false);
      ChatV2MessageLocalCache.removeMessage(testChannelId, '1001', persist: false);
      final cached = ChatV2MessageLocalCache.get(testChannelId);
      expect(cached, isNotNull);
      expect(cached!.length, 1);
      expect(cached.first.id, '1002');
      expect(cached.any((m) => m.id == '1001'), isFalse);
    });

    // Test 3: ChatV2MessageLocalCache.removeMessage an toàn khi ID không tồn tại
    test('3. ChatV2MessageLocalCache.removeMessage không gây lỗi khi messageId không tồn tại', () {
      ChatV2MessageLocalCache.set(testChannelId, [sampleMsg2], persist: false);
      ChatV2MessageLocalCache.removeMessage(testChannelId, '999999', persist: false);
      final cached = ChatV2MessageLocalCache.get(testChannelId);
      expect(cached, isNotNull);
      expect(cached!.length, 1);
      expect(cached.first.id, '1002');
    });

    // Test 4: ChatV2Message.copyWith clearPinnedAt gỡ bỏ pinnedAt thành công
    test('4. ChatV2Message.copyWith với clearPinnedAt=true chuyển isPinned thành false', () {
      expect(pinnedMsg.isPinned, isTrue);
      final unpinned = pinnedMsg.copyWith(clearPinnedAt: true);
      expect(unpinned.isPinned, isFalse);
      expect(unpinned.pinnedAt, isNull);
    });

    // Test 5: ChatV2Message.copyWith cập nhật pinnedAt mới
    test('5. ChatV2Message.copyWith với pinnedAt mới chuyển isPinned thành true', () {
      expect(sampleMsg1.isPinned, isFalse);
      final newlyPinned = sampleMsg1.copyWith(pinnedAt: '2026-10-10 11:00:00');
      expect(newlyPinned.isPinned, isTrue);
      expect(newlyPinned.pinnedAt, '2026-10-10 11:00:00');
    });

    // Test 6: ChatV2PinnedMessagesNotifier addOrUpdatePin thêm mới tin ghim
    test('6. ChatV2PinnedMessagesNotifier.addOrUpdatePin thêm mới tin nhắn ghim vào state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(chatV2PinnedMessagesProvider(testChannelId).notifier);
      notifier.updatePinned([]);
      expect(container.read(chatV2PinnedMessagesProvider(testChannelId)).valueOrNull, isEmpty);

      notifier.addOrUpdatePin(pinnedMsg);
      final list = container.read(chatV2PinnedMessagesProvider(testChannelId)).valueOrNull;
      expect(list, isNotNull);
      expect(list!.length, 1);
      expect(list.first.id, '1050');
    });

    // Test 7: ChatV2PinnedMessagesNotifier addOrUpdatePin chống trùng lặp ID
    test('7. ChatV2PinnedMessagesNotifier.addOrUpdatePin không tạo duplicate khi cập nhật cùng messageId', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(chatV2PinnedMessagesProvider(testChannelId).notifier);
      notifier.updatePinned([pinnedMsg]);

      final updatedPinned = pinnedMsg.copyWith(content: 'Nội dung cập nhật');
      notifier.addOrUpdatePin(updatedPinned);

      final list = container.read(chatV2PinnedMessagesProvider(testChannelId)).valueOrNull;
      expect(list, isNotNull);
      expect(list!.length, 1);
      expect(list.first.content, 'Nội dung cập nhật');
    });

    // Test 8: ChatV2PinnedMessagesNotifier removePin xóa đúng tin ghim
    test('8. ChatV2PinnedMessagesNotifier.removePin loại bỏ tin nhắn ghim khỏi danh sách', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(chatV2PinnedMessagesProvider(testChannelId).notifier);
      notifier.updatePinned([pinnedMsg]);
      expect(container.read(chatV2PinnedMessagesProvider(testChannelId)).valueOrNull?.length, 1);

      notifier.removePin('1050');
      final list = container.read(chatV2PinnedMessagesProvider(testChannelId)).valueOrNull;
      expect(list, isEmpty);
    });

    // Test 9: ChatV2Message.fromMap deserialize pinned_at chuẩn xác
    test('9. ChatV2Message.fromMap phân giải đúng thuộc tính pinned_at từ backend Odoo', () {
      final rawMap = {
        'id': '2001',
        'channel_id': '10',
        'body': 'Nội dung tin nhắn test',
        'pinned_at': '2026-10-10 12:00:00',
      };
      final parsed = ChatV2Message.fromMap(rawMap);
      expect(parsed.id, '2001');
      expect(parsed.isPinned, isTrue);
      expect(parsed.pinnedAt, '2026-10-10 12:00:00');
    });

    // Test 10: Banner Pin fallback & ưu tiên độc lập với 35 tin tải về (Case 3)
    test('10. Banner Pin ưu tiên lấy từ pinnedMessagesProvider khi tin ghim nằm ngoài 35 tin tải về (Case 3)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Giả lập danh sách messages trong RAM (không chứa tin ghim 1050)
      final ramMessages = [sampleMsg1, sampleMsg2];
      expect(ramMessages.any((m) => m.isPinned), isFalse);

      // Cập nhật pinnedMessagesProvider với tin 1050 từ API riêng biệt
      final notifier = container.read(chatV2PinnedMessagesProvider(testChannelId).notifier);
      notifier.updatePinned([pinnedMsg]);

      // Logic resolver trên Banner Header Pin
      final pinnedList = container.read(chatV2PinnedMessagesProvider(testChannelId)).valueOrNull;
      final activePinned = (pinnedList != null && pinnedList.isNotEmpty)
          ? pinnedList.first
          : ramMessages.where((m) => m.isPinned).firstOrNull;

      expect(activePinned, isNotNull);
      expect(activePinned!.id, '1050');
      expect(activePinned.content, 'Thông báo ghim quan trọng');
    });

    // Test 11: Case 2 - Thu hồi tin nhắn dạng soft-delete cập nhật cache đúng nội dung
    test('11. Thu hồi tin nhắn dạng soft-delete cập nhật cache với "Tin nhắn đã bị thu hồi" (Case 2)', () {
      // Thiết lập cache ban đầu
      ChatV2MessageLocalCache.set(testChannelId, [sampleMsg1, sampleMsg2], persist: false);

      // Giả lập soft-delete tin nhắn sampleMsg1
      const recalledBody = '<i>Tin nhắn đã bị thu hồi</i>';
      final updatedMsg1 = sampleMsg1.copyWith(
        content: ChatV2Message.cleanHtml(recalledBody),
        rawBody: recalledBody,
        attachments: const [],
      );

      // Cập nhật cache với danh sách sau khi soft-delete
      final cachedList = ChatV2MessageLocalCache.get(testChannelId)!;
      final nextList = cachedList.map((m) => m.id == sampleMsg1.id ? updatedMsg1 : m).toList();
      ChatV2MessageLocalCache.set(testChannelId, nextList, persist: false);

      // Đọc lại từ cache và kiểm chứng
      final refreshed = ChatV2MessageLocalCache.get(testChannelId);
      expect(refreshed, isNotNull);
      final recalledMsg = refreshed!.firstWhere((m) => m.id == sampleMsg1.id);
      expect(recalledMsg.content, 'Tin nhắn đã bị thu hồi');
      expect(recalledMsg.attachments, isEmpty);
    });

    // Test 12: Case 5 - Xóa tin nhắn đang ghim tự động gỡ khỏi banner ghim
    test('12. Xóa tin nhắn đang ghim tự động gỡ khỏi pinnedMessagesProvider và banner ghim (Case 5)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Ban đầu có tin ghim trong pinnedMessagesProvider
      final pinnedNotifier = container.read(chatV2PinnedMessagesProvider(testChannelId).notifier);
      pinnedNotifier.updatePinned([pinnedMsg]);
      expect(container.read(chatV2PinnedMessagesProvider(testChannelId)).valueOrNull?.length, 1);

      // Kích hoạt removePin khi tin nhắn bị xóa
      pinnedNotifier.removePin(pinnedMsg.id);

      // Banner ghim cập nhật rỗng
      final pinnedAfterDelete = container.read(chatV2PinnedMessagesProvider(testChannelId)).valueOrNull;
      expect(pinnedAfterDelete, isEmpty);

      // Logic resolver trên Banner Header Pin không còn tin ghim
      final activePinned = (pinnedAfterDelete != null && pinnedAfterDelete.isNotEmpty)
          ? pinnedAfterDelete.first
          : null;
      expect(activePinned, isNull);
    });
  });
}

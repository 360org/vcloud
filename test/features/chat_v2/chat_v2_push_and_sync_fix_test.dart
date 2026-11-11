import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/router/app_router.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_messages_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kiểm thử 2 lỗi thực tế: Deep Link Push & Đồng bộ Tin nhắn Cache', () {
    test('1. AppNavigationState.pendingDeepLink lưu trữ và tiêu thụ an toàn', () {
      expect(AppNavigationState.pendingDeepLink, isNull);

      // Giả lập push notification đến lúc app đang cold-start (ở /splash)
      AppNavigationState.pendingDeepLink = '/chat/42?name=Phong%20KT';
      expect(AppNavigationState.pendingDeepLink, '/chat/42?name=Phong%20KT');

      // SplashScreen tiêu thụ và reset về null
      final target = AppNavigationState.pendingDeepLink;
      AppNavigationState.pendingDeepLink = null;
      expect(target, '/chat/42?name=Phong%20KT');
      expect(AppNavigationState.pendingDeepLink, isNull);
    });

    test('2. Instant Cache Hydration: updateChannelLastMessage cập nhật ngay lập tức', () {
      final now = DateTime.now();
      ChatV2ChannelLocalCache.updateChannelLastMessage(
        '99',
        lastMessage: 'Sếp ơi em gửi báo cáo',
        lastMessageDate: now,
        authorName: 'Nguyễn Văn A',
        unreadCount: 1,
        addIfMissing: true,
      );

      final cached = ChatV2ChannelLocalCache.cached;
      final target = cached.firstWhere((c) => c.id == '99');
      expect(target.lastMessage, 'Sếp ơi em gửi báo cáo');
      expect(target.unreadCount, 1);
      expect(target.lastMessageAuthorName, 'Nguyễn Văn A');
    });

    test('3. Instant Cache Preservation: API getChannels trả về date cũ không đè mất tin Push mới', () {
      final now = DateTime.now();
      final olderDate = now.subtract(const Duration(minutes: 5));

      // 1. Giả lập tin nhắn vừa nạp từ Push notification vào cache
      ChatV2ChannelLocalCache.updateChannelLastMessage(
        '101',
        lastMessage: 'Tin nhắn cực mới từ Push',
        lastMessageDate: now,
        authorName: 'Đối tác VIP',
        unreadCount: 2,
        addIfMissing: true,
      );

      // 2. Giả lập API getChannels từ server trả về kết quả chậm hơn (mang nội dung cũ do replica lag)
      final serverChannels = [
        ChatV2Channel(
          id: '101',
          name: 'Đối tác VIP',
          channelType: 'chat',
          isGroup: false,
          memberCount: 2,
          lastMessage: 'Tin nhắn cũ từ 5 phút trước',
          lastMessageDate: olderDate,
          unreadCount: 0,
        ),
      ];

      // 3. Thực thi set(serverChannels)
      ChatV2ChannelLocalCache.set(serverChannels);

      // 4. Kiểm chứng: Tin nhắn từ Push vẫn được bảo toàn nguyên vẹn, không bị đè mất!
      final afterSet = ChatV2ChannelLocalCache.cached;
      final channel101 = afterSet.firstWhere((c) => c.id == '101');
      expect(channel101.lastMessage, 'Tin nhắn cực mới từ Push');
      expect(channel101.unreadCount, 2);
    });

    test('4. mergeMessages giữ nguyên thứ tự giảm dần và bảo toàn temp message', () {
      final now = DateTime.now();
      final tempMsg = ChatV2Message(
        id: 'temp_123456789',
        channelId: '50',
        content: 'Tin nhắn đang gửi...',
        authorId: '1',
        authorName: 'Tôi',
        createdAt: now,
        isMine: true,
        status: 'sent',
      );

      final serverMsg = ChatV2Message(
        id: '200',
        channelId: '50',
        content: 'Tin nhắn đã nhận từ server',
        authorId: '2',
        authorName: 'Đồng nghiệp',
        createdAt: now.subtract(const Duration(seconds: 10)),
        isMine: false,
        status: 'received',
      );

      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(
        [tempMsg],
        [serverMsg],
      );

      expect(merged.length, 2);
      expect(merged.first.id, 'temp_123456789'); // Tin temp mới hơn ở đầu
      expect(merged.last.id, '200');
    });

    test('5. Kênh cục bộ không có trong danh sách server vẫn được bảo tồn nếu có unread', () {
      ChatV2ChannelLocalCache.updateChannelLastMessage(
        '202',
        lastMessage: 'Tin chưa đọc từ phòng hỗ trợ',
        lastMessageDate: DateTime.now(),
        unreadCount: 3,
        addIfMissing: true,
      );

      // Server trả về danh sách không có kênh 202 (ví dụ do phân trang limit 20)
      final serverChannels = [
        ChatV2Channel(
          id: '303',
          name: 'Kênh khác',
          channelType: 'channel',
          isGroup: true,
          memberCount: 5,
          lastMessage: 'Hello',
          lastMessageDate: DateTime.now(),
        ),
      ];

      ChatV2ChannelLocalCache.set(serverChannels);

      final cached = ChatV2ChannelLocalCache.cached;
      expect(cached.any((c) => c.id == '202'), isTrue);
      final ch202 = cached.firstWhere((c) => c.id == '202');
      expect(ch202.unreadCount, 3);
    });
  });
}

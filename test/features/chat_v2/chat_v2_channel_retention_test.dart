import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kiểm thử bảo toàn Chat trong Local Cache khi out ra màn hình', () {
    setUp(() {
      ChatV2ChannelLocalCache.set([]);
    });

    test(
      '1. updateChannelLastMessage tự động thêm kênh mới vào đầu cache nếu chưa tồn tại',
      () {
        final now = DateTime.now();
        ChatV2ChannelLocalCache.updateChannelLastMessage(
          'ch_test_999',
          lastMessage: 'Chào bạn nhé!',
          lastMessageDate: now,
          authorId: 'user_1',
          authorName: 'Nguyễn Văn B',
          unreadCount: 0,
          addIfMissing: true,
        );

        final list = ChatV2ChannelLocalCache.cached;
        expect(list.length, 1);
        expect(list.first.id, 'ch_test_999');
        expect(list.first.lastMessage, 'Chào bạn nhé!');
        expect(list.first.name, 'Nguyễn Văn B');
      },
    );

    test(
      '2. pinDirectChannel bảo vệ kênh không bị xóa khi nhận danh sách mới từ server',
      () {
        const pinnedChannel = ChatV2Channel(
          id: 'ch_pinned_888',
          name: 'Trần Văn C',
          channelType: 'chat',
          isGroup: false,
          memberCount: 2,
          lastMessage: 'Tin nhắn bảo vệ',
        );

        // Ghim kênh trực tiếp
        ChatV2ChannelLocalCache.pinDirectChannel(pinnedChannel);

        // Server trả về danh sách trống hoặc không chứa ch_pinned_888
        final serverFreshChannels = <ChatV2Channel>[
          const ChatV2Channel(
            id: 'ch_other_111',
            name: 'Nhóm Dự Án',
            channelType: 'channel',
            isGroup: true,
            memberCount: 5,
          ),
        ];

        ChatV2ChannelLocalCache.set(serverFreshChannels);

        final cachedList = ChatV2ChannelLocalCache.cached;
        final cachedIds = cachedList.map((c) => c.id).toList();

        // Kênh ch_pinned_888 VẪN PHẢI TỒN TẠI trong cache nhờ được bảo vệ
        expect(cachedIds, contains('ch_pinned_888'));
        expect(cachedIds, contains('ch_other_111'));
        expect(
          cachedList.firstWhere((c) => c.id == 'ch_pinned_888').lastMessage,
          'Tin nhắn bảo vệ',
        );
      },
    );

    test(
      '3. Chat từ thông báo nạp vào cache và bảo toàn qua các chu kỳ refresh server',
      () {
        // Giả lập kênh từ thông báo đẩy hoặc bottom sheet thông báo
        const notifChannel = ChatV2Channel(
          id: '1399',
          name: 'Vũ Việt Hùng',
          channelType: 'chat',
          isGroup: false,
          memberCount: 2,
          lastMessage: 'ĐÃ XEM TIN NHẮN',
        );

        // Pin kênh này khi mở hoặc khi tương tác
        ChatV2ChannelLocalCache.pinDirectChannel(notifChannel);

        // Server trả về danh sách không hề chứa kênh 1399 (do chưa có tin nhắn chưa đọc)
        final serverChannelsWithout1399 = <ChatV2Channel>[
          const ChatV2Channel(
            id: '2001',
            name: 'Nguyễn Đào Quốc Anh',
            channelType: 'chat',
            isGroup: false,
            memberCount: 2,
            lastMessage: 'Dạ anh',
          ),
        ];

        // Khi ChatV2ChannelLocalCache.set() được gọi (từ fetchFreshChannels hoặc resumeRefresh)
        ChatV2ChannelLocalCache.set(serverChannelsWithout1399);

        final list = ChatV2ChannelLocalCache.cached;
        final ids = list.map((c) => c.id).toList();

        // Kênh 1399 (Vũ Việt Hùng) bắt buộc phải luôn luôn có mặt trong danh sách hội thoại
        expect(ids, contains('1399'));
        final hung = list.firstWhere((c) => c.id == '1399');
        expect(hung.name, 'Vũ Việt Hùng');
        expect(hung.lastMessage, 'ĐÃ XEM TIN NHẮN');
      },
    );

    test(
      '4. Server trả về kênh có lastMessage rỗng không đè mất lastMessage đã lưu trong pinned/cache',
      () {
        final now = DateTime.now();
        final localChannel = ChatV2Channel(
          id: '9999',
          name: 'Nhàn Trần',
          channelType: 'chat',
          isGroup: false,
          memberCount: 2,
          lastMessage: 'Cám ơn em đã hỗ trợ',
          lastMessageDate: now,
        );

        ChatV2ChannelLocalCache.pinDirectChannel(localChannel);

        // Server trả về kênh Nhàn Trần nhưng lastMessage bị null/rỗng
        final serverChannels = <ChatV2Channel>[
          ChatV2Channel(
            id: '9999',
            name: 'Nhàn Trần',
            channelType: 'chat',
            isGroup: false,
            memberCount: 2,
            lastMessage: null,
            lastMessageDate: now.subtract(const Duration(minutes: 5)),
          ),
        ];

        ChatV2ChannelLocalCache.set(serverChannels);

        final list = ChatV2ChannelLocalCache.cached;
        final nhanTran = list.firstWhere((c) => c.id == '9999');
        expect(nhanTran.lastMessage, 'Cám ơn em đã hỗ trợ');
      },
    );
  });
}

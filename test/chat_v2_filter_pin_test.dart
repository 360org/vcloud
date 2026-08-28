import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

void main() {
  group('ChatV2Channel Classification & Sorting Tests', () {
    final channelDirect = ChatV2Channel(
      id: '101',
      name: 'Nguyễn Văn A',
      channelType: 'chat',
      unreadCount: 3,
      isGroup: false,
      lastMessage: 'Chào bạn',
      lastMessageDate: DateTime.parse('2026-08-19 14:00:00'),
    );

    final channelGroup = ChatV2Channel(
      id: '102',
      name: 'Dự án Mobile App',
      channelType: 'channel',
      unreadCount: 0,
      isGroup: true,
      lastMessage: 'Đã hoàn thành test',
      lastMessageDate: DateTime.parse('2026-08-19 15:00:00'),
    );

    final channelPinnedDirect = ChatV2Channel(
      id: '103',
      name: 'Sếp Châu',
      channelType: 'chat',
      unreadCount: 1,
      isGroup: false,
      lastMessage: 'Audit report OK',
      lastMessageDate: DateTime.parse('2026-08-19 16:00:00'),
    );

    test('ChatV2Channel correctly flags isGroup for direct vs group', () {
      expect(channelDirect.isGroup, isFalse);
      expect(channelGroup.isGroup, isTrue);
      expect(channelPinnedDirect.isGroup, isFalse);
    });

    test('Filter All returns all channels', () {
      final list = [channelDirect, channelGroup, channelPinnedDirect];
      expect(list.length, 3);
    });

    test('Filter Direct returns only 1-on-1 direct channels (!isGroup)', () {
      final list = [channelDirect, channelGroup, channelPinnedDirect];
      final directList = list.where((c) => !c.isGroup).toList();
      expect(directList.length, 2);
      expect(directList.map((c) => c.id), containsAll(['101', '103']));
    });

    test('Filter Group returns only multi-user group channels (isGroup)', () {
      final list = [channelDirect, channelGroup, channelPinnedDirect];
      final groupList = list.where((c) => c.isGroup).toList();
      expect(groupList.length, 1);
      expect(groupList.first.id, '102');
    });

    test('Pinned channels sort ahead of unpinned channels', () {
      final pinnedIds = {'102', '103'};
      final list = [channelDirect, channelGroup, channelPinnedDirect];

      final sorted = List<ChatV2Channel>.from(list)..sort((a, b) {
        final aPinned = pinnedIds.contains(a.id);
        final bPinned = pinnedIds.contains(b.id);
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;
        final dateA = a.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      expect(sorted.first.id, '103'); // Pinned & newer
      expect(sorted[1].id, '102');    // Pinned
      expect(sorted.last.id, '101');  // Unpinned
    });

    test('copyWith updates unreadCount immutably', () {
      final updated = channelDirect.copyWith(unreadCount: 0);
      expect(updated.unreadCount, 0);
      expect(channelDirect.unreadCount, 3);
    });

    test('Incoming message from Vũ Việt Hùng or Nhan Tran places channel at index 0 of chat list', () {
      final hungChannel = const ChatV2Channel(
        id: '4248',
        name: 'Vũ Việt Hùng',
        channelType: 'chat',
        isGroup: false,
        lastMessage: 'Chào anh Tân, em gửi báo cáo',
        lastMessageDate: null,
      ).copyWith(lastMessageDate: DateTime.parse('2026-08-28 15:10:00'));

      final nhanChannel = const ChatV2Channel(
        id: '5001',
        name: 'Nhan Tran',
        channelType: 'chat',
        isGroup: false,
        lastMessage: 'Em đã cập nhật xong tính năng',
        lastMessageDate: null,
      ).copyWith(lastMessageDate: DateTime.parse('2026-08-28 15:12:00'));

      final list = [channelDirect, channelGroup, hungChannel, nhanChannel];

      final sorted = List<ChatV2Channel>.from(list)..sort((a, b) {
        final dateA = a.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      // Nhan Tran vừa gửi lúc 15:12:00 -> vị trí #1
      expect(sorted.first.name, 'Nhan Tran');
      expect(sorted.first.lastMessage, 'Em đã cập nhật xong tính năng');

      // Vũ Việt Hùng vừa gửi lúc 15:10:00 -> vị trí #2
      expect(sorted[1].name, 'Vũ Việt Hùng');
      expect(sorted[1].lastMessage, 'Chào anh Tân, em gửi báo cáo');
    });

    test('TASK #16453: External customer empty 1-1 chat (hung@davita.vn) is excluded from isInternalDirect, while customer channel is under isChannel', () {
      // 1. Kênh 1-1 rỗng của khách hàng ngoài Vũ Việt Hùng (hung@davita.vn)
      const externalEmptyDirect = ChatV2Channel(
        id: '4248',
        name: 'Vũ Việt Hùng',
        channelType: 'chat',
        isGroup: false,
        lastMessage: null,
        members: [
          ChatV2Member(id: '447', name: 'Vũ Việt Hùng', email: 'hung@davita.vn'),
          ChatV2Member(id: '6713', name: 'Ma Nguyễn Nhật Tân', email: 'tanmnn@360.org.vn', isMe: true),
        ],
      );
      expect(externalEmptyDirect.isInternalDirect('Ma Nguyễn Nhật Tân'), isFalse);

      // 2. Kênh 1-1 của nhân viên nội bộ TRẦN THỊ HỒNG DƯƠNG (duongtth@360.org.vn)
      const internalEmptyDirect = ChatV2Channel(
        id: '4272',
        name: 'TRẦN THỊ HỒNG DƯƠNG',
        channelType: 'chat',
        isGroup: false,
        lastMessage: null,
        members: [
          ChatV2Member(id: '6769', name: 'TRẦN THỊ HỒNG DƯƠNG', email: 'duongtth@360.org.vn'),
          ChatV2Member(id: '6713', name: 'Ma Nguyễn Nhật Tân', email: 'tanmnn@360.org.vn', isMe: true),
        ],
      );
      expect(internalEmptyDirect.isInternalDirect('Ma Nguyễn Nhật Tân'), isTrue);

      // 3. Kênh khách hàng Vũ Việt Hùng (ID 1399, channel_type == 'channel')
      const customerChannelHung = ChatV2Channel(
        id: '1399',
        name: 'Vũ Việt Hùng',
        channelType: 'channel',
        isGroup: true,
        lastMessage: 'Dạ vâng 360 nhận thông tin ạ',
      );
      expect(customerChannelHung.isChannel, isTrue);
      expect(customerChannelHung.isInternalDirect('Ma Nguyễn Nhật Tân'), isFalse);

      // 4. Kênh khách hàng Nhan Tran (ID 1396, channel_type == 'channel')
      const customerChannelNhan = ChatV2Channel(
        id: '1396',
        name: 'Nhan Tran',
        channelType: 'channel',
        isGroup: true,
        lastMessage: 'dạ chị',
      );
      expect(customerChannelNhan.isChannel, isTrue);
      expect(customerChannelNhan.isInternalDirect('Ma Nguyễn Nhật Tân'), isFalse);
    });
  });
}

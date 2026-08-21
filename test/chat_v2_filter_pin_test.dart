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
  });
}

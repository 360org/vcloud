import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat V2 Channel Categorization & Search Unit Tests', () {
    final now = DateTime.now();

    final directChannel = ChatV2Channel(
      id: '101',
      name: 'Chau, Le Ba',
      channelType: 'chat',
      isGroup: false,
      memberCount: 2,
      lastMessage: 'Hello anh',
      lastMessageDate: now.subtract(const Duration(minutes: 5)),
      directPartnerName: 'Chau, Le Ba',
    );

    final internalChannel = ChatV2Channel(
      id: '202',
      name: 'Internal',
      channelType: 'channel',
      isGroup: true,
      memberCount: 25,
      lastMessage: r'$AIAC="$env:USERPROFILE\.360-aiac"',
      lastMessageDate: now.subtract(const Duration(hours: 1)),
    );

    final groupChannel = ChatV2Channel(
      id: '303',
      name: 'Team Dev Mobile',
      channelType: 'group',
      isGroup: true,
      memberCount: 5,
      lastMessage: 'Release version mới nhé',
      lastMessageDate: now.subtract(const Duration(days: 1)),
    );

    final livechatCustomerChannel = ChatV2Channel(
      id: '404',
      name: 'Luong Van Chi',
      channelType: 'channel',
      isGroup: false,
      memberCount: 2,
      lastMessage: 'Chí: a cam on e',
      lastMessageDate: now.subtract(const Duration(minutes: 15)),
      unreadCount: 3,
    );

    test('Phân loại kênh Internal là Kênh thảo luận (isChannel = true)', () {
      expect(internalChannel.isChannel, isTrue);
      expect(internalChannel.channelType, equals('channel'));
      expect(internalChannel.isGroupChat('Tan'), isFalse); // Loại trừ channel khỏi group chat
      expect(internalChannel.isInternalDirect('Tan'), isFalse);
    });

    test('Phân loại chat 1-1 Chau, Le Ba là Trò chuyện nội bộ (isInternalDirect = true)', () {
      expect(directChannel.isInternalDirect('Tan'), isTrue);
      expect(directChannel.isChannel, isFalse);
      expect(directChannel.isGroupChat('Tan'), isFalse);
    });

    test('Phân loại Team Dev Mobile là Nhóm trò chuyện (isGroupChat = true)', () {
      expect(groupChannel.isGroupChat('Tan'), isTrue);
      expect(groupChannel.isChannel, isFalse);
      expect(groupChannel.isInternalDirect('Tan'), isFalse);
    });

    test('Tìm kiếm theo tên kênh "Internal" khớp chính xác không phân biệt hoa thường', () {
      final list = [directChannel, internalChannel, groupChannel, livechatCustomerChannel];
      const query = 'internal';

      final results = list.where((c) {
        final cleanName = c.getCleanName('Tan');
        return cleanName.toLowerCase().contains(query) ||
            c.name.toLowerCase().contains(query) ||
            (c.lastMessage ?? '').toLowerCase().contains(query);
      }).toList();

      expect(results.length, equals(1));
      expect(results.first.id, equals('202'));
      expect(results.first.name, equals('Internal'));
    });

    test('Tìm kiếm theo nội dung tin nhắn "powershell / AIAC" tìm ra kênh Internal', () {
      final list = [directChannel, internalChannel, groupChannel, livechatCustomerChannel];
      const query = 'aiac';

      final results = list.where((c) {
        final cleanName = c.getCleanName('Tan');
        return cleanName.toLowerCase().contains(query) ||
            c.name.toLowerCase().contains(query) ||
            (c.lastMessage ?? '').toLowerCase().contains(query);
      }).toList();

      expect(results.length, equals(1));
      expect(results.first.name, equals('Internal'));
    });

    test('Sắp xếp kênh giảm dần theo lastMessageDate', () {
      final list = [groupChannel, directChannel, internalChannel, livechatCustomerChannel];

      list.sort((a, b) {
        final da = a.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

      // Thứ tự: directChannel (5m) -> livechatCustomerChannel (15m) -> internalChannel (1h) -> groupChannel (1d)
      expect(list[0].id, equals('101'));
      expect(list[1].id, equals('404'));
      expect(list[2].id, equals('202')); // Internal Channel
      expect(list[3].id, equals('303'));
    });

    test('ChatV2ChannelLocalCache nạp và cập nhật danh sách kênh thành công', () {
      ChatV2ChannelLocalCache.set([directChannel, internalChannel, groupChannel]);
      final cached = ChatV2ChannelLocalCache.cached;

      expect(cached.any((c) => c.name == 'Internal'), isTrue);
      expect(cached.length, equals(3));
    });
  });
}

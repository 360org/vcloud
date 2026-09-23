import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

void main() {
  group('ChatV2Channel Display Name Resolution & Mapping Tests', () {
    const currentUserName = 'Sếp Tân';

    test('1. Internal channel with direct partner displays participant name alongside channel name', () {
      const channel = ChatV2Channel(
        id: '101',
        name: 'Internal',
        channelType: 'channel',
        isGroup: true,
        directPartnerName: 'Nguyễn Hoàng Khang',
        memberCount: 2,
      );

      final cleanName = channel.getCleanName(currentUserName);
      expect(cleanName, equals('Nguyễn Hoàng Khang (Internal)'));
    });

    test('2. Internal channel without participant name displays bare channel name', () {
      const channel = ChatV2Channel(
        id: '102',
        name: 'Internal',
        channelType: 'channel',
        isGroup: true,
        memberCount: 1,
      );

      final cleanName = channel.getCleanName(currentUserName);
      expect(cleanName, equals('Internal'));
    });

    test('3. Direct 1-1 chat with comma-separated names resolves only the other person', () {
      const channel = ChatV2Channel(
        id: '103',
        name: 'Sếp Tân, Nguyễn Hoàng Khang',
        channelType: 'chat',
        isGroup: false,
        directPartnerName: 'Nguyễn Hoàng Khang',
        memberCount: 2,
      );

      final cleanName = channel.getCleanName(currentUserName);
      expect(cleanName, equals('Nguyễn Hoàng Khang'));
    });

    test('4. Direct 1-1 chat whose name is already partner name keeps partner name', () {
      const channel = ChatV2Channel(
        id: '104',
        name: 'Nguyễn Hoàng Khang',
        channelType: 'chat',
        isGroup: false,
        directPartnerName: 'Nguyễn Hoàng Khang',
        memberCount: 2,
      );

      final cleanName = channel.getCleanName(currentUserName);
      expect(cleanName, equals('Nguyễn Hoàng Khang'));
    });

    test('5. Multi-person group chat keeps group name without adding arbitrary member', () {
      const channel = ChatV2Channel(
        id: '105',
        name: 'Ban Giám Đốc',
        channelType: 'group',
        isGroup: true,
        memberCount: 6,
        members: [
          ChatV2Member(id: '1', name: 'Sếp Tân', isMe: true),
          ChatV2Member(id: '2', name: 'Nguyễn Hoàng Khang'),
          ChatV2Member(id: '3', name: 'Lê Văn B'),
          ChatV2Member(id: '4', name: 'Trần Thị C'),
        ],
      );

      final cleanName = channel.getCleanName(currentUserName);
      expect(cleanName, equals('Ban Giám Đốc'));
    });

    test('6. Non-internal named channel with participant displays participant alongside channel name', () {
      const channel = ChatV2Channel(
        id: '106',
        name: 'Hỗ trợ khách hàng',
        channelType: 'channel',
        isGroup: true,
        directPartnerName: 'Lê Văn B',
        memberCount: 2,
      );

      final cleanName = channel.getCleanName(currentUserName);
      expect(cleanName, equals('Lê Văn B (Hỗ trợ khách hàng)'));
    });

    test('7. Internal channel resolves participant from members list when directPartnerName is absent', () {
      const channel = ChatV2Channel(
        id: '107',
        name: 'Internal',
        channelType: 'channel',
        isGroup: true,
        memberCount: 2,
        members: [
          ChatV2Member(id: '1', name: 'Sếp Tân', isMe: true),
          ChatV2Member(id: '2', name: 'Nguyễn Hoàng Khang'),
        ],
      );

      final cleanName = channel.getCleanName(currentUserName);
      expect(cleanName, equals('Nguyễn Hoàng Khang (Internal)'));
    });

    test('8. Empty channel name falls back to default label', () {
      const channel = ChatV2Channel(
        id: '108',
        name: '',
        channelType: 'chat',
      );

      final cleanName = channel.getCleanName(currentUserName);
      expect(cleanName, equals('Cuộc trò chuyện'));
    });

    test('9. Null or empty current user name falls back to channel name', () {
      const channel = ChatV2Channel(
        id: '109',
        name: 'Internal',
        channelType: 'channel',
      );

      expect(channel.getCleanName(null), equals('Internal'));
      expect(channel.getCleanName('   '), equals('Internal'));
    });

    test('10. ChatV2Channel.fromJson populates directPartnerName for 2-member channel', () {
      final json = {
        'id': 110,
        'name': 'Internal',
        'channel_type': 'channel',
        'is_group': true,
        'member_count': 2,
        'members': [
          {'id': 1, 'name': 'Sếp Tân', 'is_me': true},
          {'id': 2, 'name': 'Đặng Minh Châu', 'is_me': false},
        ],
      };

      final parsed = ChatV2Channel.fromJson(json);
      expect(parsed.directPartnerName, equals('Đặng Minh Châu'));
      expect(parsed.getCleanName(currentUserName), equals('Đặng Minh Châu (Internal)'));
    });
  });
}

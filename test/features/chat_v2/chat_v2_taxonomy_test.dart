import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

void main() {
  group('Chat V2 4-Category Taxonomy & Filter Tests', () {
    const currentUserName = 'Nguyen Nhat Tan';

    test('Case 1: Direct 1-1 conversation is correctly classified', () {
      const directCh = ChatV2Channel(
        id: '101',
        name: 'Chau, Le Ba',
        channelType: 'chat',
        isGroup: false,
        memberCount: 2,
        directPartnerId: '55',
        directPartnerName: 'Chau, Le Ba',
      );

      expect(directCh.isInternalDirect(currentUserName), isTrue);
      expect(directCh.isGroupChat(currentUserName), isFalse);
      expect(directCh.isChannel, isFalse);
      expect(directCh.isZaloOA, isFalse);
    });

    test('Case 2: Discussion channel (channelType == "channel") is classified as isChannel', () {
      const channelCh = ChatV2Channel(
        id: '102',
        name: 'Internal Dev Team',
        channelType: 'channel',
        isGroup: false,
        memberCount: 15,
      );

      expect(channelCh.isChannel, isTrue);
      expect(channelCh.isInternalDirect(currentUserName), isFalse);
      expect(channelCh.isGroupChat(currentUserName), isFalse);
      expect(channelCh.isZaloOA, isFalse);
    });

    test('Case 3: Group chat (isGroup == true) is classified as isGroupChat', () {
      const groupCh = ChatV2Channel(
        id: '103',
        name: 'Ban Lãnh Đạo 360',
        channelType: 'group',
        isGroup: true,
        memberCount: 5,
      );

      expect(groupCh.isGroupChat(currentUserName), isTrue);
      expect(groupCh.isInternalDirect(currentUserName), isFalse);
      expect(groupCh.isChannel, isFalse);
      expect(groupCh.isZaloOA, isFalse);
    });

    test('Case 4: Zalo OA by channelType == "zalo" is classified as isZaloOA', () {
      const zaloCh = ChatV2Channel(
        id: '104',
        name: 'Khách hàng Nguyễn Văn A',
        channelType: 'zalo',
        isGroup: false,
        memberCount: 2,
      );

      expect(zaloCh.isZaloOA, isTrue);
      expect(zaloCh.isInternalDirect(currentUserName), isFalse);
      expect(zaloCh.isChannel, isFalse);
    });

    test('Case 5: Zalo OA by channelType == "zalo_oa" is classified as isZaloOA', () {
      const zaloCh = ChatV2Channel(
        id: '105',
        name: 'Cửa hàng Trần Phú',
        channelType: 'zalo_oa',
        isGroup: false,
        memberCount: 2,
      );

      expect(zaloCh.isZaloOA, isTrue);
      expect(zaloCh.isInternalDirect(currentUserName), isFalse);
    });

    test('Case 6: Livechat / Customer conversation by channelType == "livechat" is classified as isZaloOA', () {
      const livechatCh = ChatV2Channel(
        id: '106',
        name: 'Khách hàng ghé thăm Website',
        channelType: 'livechat',
        isGroup: false,
        memberCount: 2,
      );

      expect(livechatCh.isZaloOA, isTrue);
      expect(livechatCh.isInternalDirect(currentUserName), isFalse);
    });

    test('Case 7: Channel with name containing "zalo" is classified as isZaloOA', () {
      const zaloNameCh = ChatV2Channel(
        id: '107',
        name: 'Tư vấn Zalo OA - Khách hàng VIP',
        channelType: 'chat',
        isGroup: false,
        memberCount: 2,
      );

      expect(zaloNameCh.isZaloOA, isTrue);
      expect(zaloNameCh.isInternalDirect(currentUserName), isFalse);
    });

    test('Case 8: Channel getCleanName preserves channel title', () {
      const channelCh = ChatV2Channel(
        id: '108',
        name: 'Kênh Thông Báo Chung',
        channelType: 'channel',
        isGroup: false,
      );

      expect(channelCh.getCleanName(currentUserName), equals('Kênh Thông Báo Chung'));
    });

    test('Case 9: Group getCleanName preserves group title', () {
      const groupCh = ChatV2Channel(
        id: '109',
        name: 'Dự án VCloud Mobile',
        channelType: 'group',
        isGroup: true,
      );

      expect(groupCh.getCleanName(currentUserName), equals('Dự án VCloud Mobile'));
    });

    test('Case 10: 6 Filter Categories partition conversations correctly', () {
      final channels = [
        const ChatV2Channel(id: '1', name: '1-1 Direct', channelType: 'chat', isGroup: false),
        const ChatV2Channel(id: '2', name: 'Dev Channel', channelType: 'channel', isGroup: false),
        const ChatV2Channel(id: '3', name: 'Ops Group', channelType: 'group', isGroup: true),
        const ChatV2Channel(id: '4', name: 'Zalo Support', channelType: 'zalo', isGroup: false),
      ];

      final direct = channels.where((c) => c.isInternalDirect(currentUserName)).toList();
      final channel = channels.where((c) => c.isChannel).toList();
      final group = channels.where((c) => c.isGroupChat(currentUserName)).toList();
      final zalo = channels.where((c) => c.isZaloOA).toList();

      expect(direct.length, equals(1));
      expect(direct.first.id, equals('1'));

      expect(channel.length, equals(1));
      expect(channel.first.id, equals('2'));

      expect(group.length, equals(1));
      expect(group.first.id, equals('3'));

      expect(zalo.length, equals(1));
      expect(zalo.first.id, equals('4'));
    });
  });
}

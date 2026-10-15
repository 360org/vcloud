import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

void main() {
  group('Portal CSKH Channel Model Tests (TC-01..TC-10)', () {
    test('TC-08a: fromJson with is_cskh_channel parses correctly', () {
      final json = {
        'id': '2250',
        'name': 'Chăm Sóc Khách Hàng 360',
        'channel_type': 'group',
        'is_group': true,
        'is_cskh_channel': true,
        'avatar_url': '/api/v1/mobile/avatar/res.company/1?field=logo',
        'is_new': true,
        'unread_count': 0,
      };

      final channel = ChatV2Channel.fromJson(json);

      expect(channel.id, '2250');
      expect(channel.isCskhChannel, isTrue);
      expect(channel.isGroup, isTrue);
      expect(channel.displayName, 'Chăm Sóc Khách Hàng 360');
      expect(channel.getCleanName('Khách Hàng A'), 'Chăm Sóc Khách Hàng 360');
    });

    test('TC-08b: fromJson with [CSKH] in name automatically marks isCskhChannel', () {
      final json = {
        'id': '2251',
        'name': '[CSKH] Công ty Cổ phần ABC',
        'channel_type': 'group',
        'is_group': true,
        'unread_count': 1,
      };

      final channel = ChatV2Channel.fromJson(json);

      expect(channel.id, '2251');
      expect(channel.isCskhChannel, isTrue);
      expect(channel.isGroup, isTrue);
    });

    test('TC-08c: toMap preserves is_cskh_channel', () {
      const channel = ChatV2Channel(
        id: '2252',
        name: 'Chăm Sóc Khách Hàng 360',
        channelType: 'group',
        isGroup: true,
        isCskhChannel: true,
      );

      final map = channel.toMap();
      expect(map['is_cskh_channel'], isTrue);
      expect(map['name'], 'Chăm Sóc Khách Hàng 360');
      expect(map['channel_type'], 'group');
    });

    test('TC-08d: copyWith updates isCskhChannel correctly', () {
      const channel = ChatV2Channel(
        id: '2253',
        name: 'Kênh Test',
      );

      expect(channel.isCskhChannel, isFalse);

      final updated = channel.copyWith(isCskhChannel: true);
      expect(updated.isCskhChannel, isTrue);
      expect(updated.id, '2253');
    });

    test('TC-08e: Brand masking leaves no Admin name in CSKH title', () {
      final json = {
        'id': '2254',
        'name': 'Chăm Sóc Khách Hàng 360',
        'channel_type': 'group',
        'is_group': true,
        'is_cskh_channel': true,
      };

      final channel = ChatV2Channel.fromJson(json);

      expect(channel.displayName.toLowerCase().contains('admin'), isFalse);
      expect(channel.getCleanName('Portal User').toLowerCase().contains('admin'), isFalse);
    });

    test('TC-11: Livechat channel displays service name not Admin for Portal user', () {
      final json = {
        'id': '665804',
        'name': 'Technical Support',
        'channel_type': 'livechat',
        'is_group': false,
        'is_cskh_channel': true,
        'direct_partner_name': null,
        'avatar_url': '/web/image/im_livechat.channel/2/image_128',
      };

      final channel = ChatV2Channel.fromJson(json);

      expect(channel.id, '665804');
      expect(channel.channelType, 'livechat');
      expect(channel.displayName, 'Technical Support');
      expect(channel.getCleanName('Khách Hàng Mới', isPortal: true), 'Technical Support');
      expect(channel.avatarUrl, contains('/web/image/im_livechat.channel/2/image_128'));
    });

    test('TC-12: Livechat fromJson prevents operator Admin from overriding channel title', () {
      final json = {
        'id': '665805',
        'name': 'Customer Care',
        'channel_type': 'livechat',
        'is_group': false,
        'members': [
          {'id': '3618', 'name': 'Khách Hàng Mới', 'is_me': true},
          {'id': '3', 'name': 'Mitchell Admin', 'is_me': false},
        ],
        'avatar_url': '/web/image/im_livechat.channel/1/image_128',
      };

      final channel = ChatV2Channel.fromJson(json);

      expect(channel.id, '665805');
      expect(channel.channelType, 'livechat');
      expect(channel.displayName, 'Customer Care');
      expect(channel.getCleanName('Khách Hàng Mới', isPortal: true), 'Customer Care');
      expect(channel.directPartnerName, isNull);
    });
  });
}

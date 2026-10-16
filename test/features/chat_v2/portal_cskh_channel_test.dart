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

    test('TC-13: Livechat channel isolates from CSKH and keeps distinct Livechat clean name', () {
      final json = {
        'id': '665806',
        'name': 'Technical Support',
        'channel_type': 'livechat',
        'is_group': false,
        'is_cskh_channel': true,
      };

      final channel = ChatV2Channel.fromJson(json);

      expect(channel.channelType, 'livechat');
      expect(channel.isCskhChannel, isFalse);
      // Clean name must NOT be overwritten to generic group CSKH title
      expect(channel.getCleanName('Portal User', isPortal: true), 'Technical Support');
    });

    test('TC-14: Livechat channel with generic or empty name falls back to "Hỗ trợ trực tuyến"', () {
      final json = {
        'id': '665807',
        'name': 'Cuộc trò chuyện',
        'channel_type': 'livechat',
        'is_group': false,
      };

      final channel = ChatV2Channel.fromJson(json);

      expect(channel.channelType, 'livechat');
      expect(channel.getCleanName('Portal User', isPortal: true), 'Hỗ trợ trực tuyến');
    });

    test('TC-15: Group CSKH channel strips [CSKH] prefix or returns brand name for Portal user', () {
      final jsonSpecific = {
        'id': '665808',
        'name': '[CSKH] Hợp đồng DV 2026',
        'channel_type': 'group',
        'is_group': true,
        'is_cskh_channel': true,
      };

      final channelSpecific = ChatV2Channel.fromJson(jsonSpecific);
      expect(channelSpecific.channelType, 'group');
      expect(channelSpecific.isCskhChannel, isTrue);
      expect(channelSpecific.getCleanName('Portal User', isPortal: true), 'Hợp đồng DV 2026');

      final jsonGeneric = {
        'id': '665809',
        'name': '[CSKH]',
        'channel_type': 'group',
        'is_group': true,
        'is_cskh_channel': true,
      };

      final channelGeneric = ChatV2Channel.fromJson(jsonGeneric);
      expect(channelGeneric.getCleanName('Portal User', isPortal: true), 'Chăm Sóc Khách Hàng 360');
    });

    test('TC-16: [B.10] Livechat channels are strictly isolated from groups', () {
      final json = {
        'id': '665810',
        'name': 'Khách Hàng Mới • Technical Support',
        'channel_type': 'livechat',
        'is_group': true, // Even if raw is_group is true from backend
        'members': [
          {'id': '10', 'name': 'Khách Hàng Mới', 'is_me': false},
          {'id': '3', 'name': 'Mitchell Admin', 'is_me': true},
          {'id': '5', 'name': 'Operator 2', 'is_me': false},
        ],
      };

      final channel = ChatV2Channel.fromJson(json);

      expect(channel.isLivechat, isTrue);
      expect(channel.isGroupChat('Mitchell Admin'), isFalse);
      expect(channel.getActualIsGroup('Mitchell Admin'), isFalse);
    });

    test('TC-17: [B.11] Operator perspective displays Customer Name • Service Name', () {
      final json = {
        'id': '665811',
        'name': 'Khách Hàng Mới • Technical Support',
        'channel_type': 'livechat',
        'livechat_channel_name': 'Technical Support',
        'direct_partner_name': 'Khách Hàng Mới',
        'members': [
          {'id': '10', 'name': 'Khách Hàng Mới', 'is_me': false},
          {'id': '3', 'name': 'Mitchell Admin', 'is_me': true},
        ],
      };

      final channel = ChatV2Channel.fromJson(json);

      // Operator perspective
      final operatorCleanName = channel.getCleanName('Mitchell Admin', isPortal: false);
      expect(operatorCleanName, 'Khách Hàng Mới • Technical Support');

      // Portal perspective
      final portalCleanName = channel.getCleanName('Khách Hàng Mới', isPortal: true);
      expect(portalCleanName, 'Technical Support');
    });

    test('TC-18: [B.12] 1-1 direct chat displays counterparty name instead of Admin', () {
      final json = {
        'id': '665812',
        'name': 'Admin', // Bug condition: Odoo raw channel name was "Admin"
        'channel_type': 'chat',
        'is_group': false,
        'direct_partner_name': 'Admin', // Bug condition: directPartnerName was self
        'members': [
          {'id': '3', 'name': 'Admin', 'is_me': true},
          {'id': '10', 'name': 'Nguyễn Văn Nam', 'is_me': false},
        ],
      };

      final channel = ChatV2Channel.fromJson(json);

      final cleanName = channel.getCleanName('Admin', isPortal: false);
      expect(cleanName, 'Nguyễn Văn Nam');
      expect(cleanName.contains('Admin'), isFalse);
    });

    test('TC-19: [B.14] Livechat channel preserves livechat_channel_name in fromJson, toMap, copyWith', () {
      final json = {
        'id': '665813',
        'name': 'Customer Care',
        'channel_type': 'livechat',
        'livechat_channel_name': 'Customer Care',
      };

      final channel = ChatV2Channel.fromJson(json);
      expect(channel.livechatChannelName, 'Customer Care');

      final map = channel.toMap();
      expect(map['livechat_channel_name'], 'Customer Care');

      final copied = channel.copyWith(livechatChannelName: 'Technical Support');
      expect(copied.livechatChannelName, 'Technical Support');
    });

    test('TC-20: [B.15] Livechat channel never receives CSKH badge, strictly reserved for [CSKH] groups', () {
      final jsonLivechat = {
        'id': '665814',
        'name': 'Technical Support',
        'channel_type': 'livechat',
        'is_cskh_channel': true, // Attempted to set CSKH
      };

      final channelLivechat = ChatV2Channel.fromJson(jsonLivechat);
      expect(channelLivechat.isLivechat, isTrue);
      expect(channelLivechat.isCskhChannel, isFalse);

      final jsonGroup = {
        'id': '665815',
        'name': '[CSKH] Hỗ trợ VIP',
        'channel_type': 'group',
        'is_group': true,
      };

      final channelGroup = ChatV2Channel.fromJson(jsonGroup);
      expect(channelGroup.isLivechat, isFalse);
      expect(channelGroup.isCskhChannel, isTrue);
    });
  });
}

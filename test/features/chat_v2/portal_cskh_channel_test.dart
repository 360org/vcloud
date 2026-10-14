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
  });
}

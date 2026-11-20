import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

void main() {
  group('Chat V2 Server-Driven Dynamic Filter & Inheritance Tests', () {
    test('Case 1: Channel with backend category zalo_oa resolves effectiveCategory correctly', () {
      const ch = ChatV2Channel(
        id: '201',
        name: 'Zalo OA CSKH 360 CORP',
        channelType: 'zalo_oa',
        category: 'zalo_oa',
        categoryLabel: 'Zalo OA',
        isZaloOAChannel: true,
      );

      expect(ch.effectiveCategory, equals('zalo_oa'));
      expect(ch.effectiveCategoryLabel, equals('Zalo OA'));
      expect(ch.isZaloOA, isTrue);
      expect(ch.isZaloPersonal, isFalse);
    });

    test('Case 2: Channel with backend category zalo (personal) resolves effectiveCategory correctly', () {
      const ch = ChatV2Channel(
        id: '202',
        name: 'Zalo Nguyen Van B',
        channelType: 'zalo',
        category: 'zalo',
        categoryLabel: 'Zalo',
        isZaloPersonalChannel: true,
      );

      expect(ch.effectiveCategory, equals('zalo'));
      expect(ch.effectiveCategoryLabel, equals('Zalo'));
      expect(ch.isZaloPersonal, isTrue);
      expect(ch.isZaloOA, isFalse);
    });

    test('Case 3: Channel with custom future backend category (e.g. telegram) inherits dynamically', () {
      const ch = ChatV2Channel(
        id: '203',
        name: 'Telegram VIP Support',
        channelType: 'telegram',
        category: 'telegram',
        categoryLabel: 'Telegram Support',
      );

      expect(ch.effectiveCategory, equals('telegram'));
      expect(ch.effectiveCategoryLabel, equals('Telegram Support'));
    });

    test('Case 4: Channel with isZaloOAChannel distinguishes from personal Zalo', () {
      const ch = ChatV2Channel(
        id: '204',
        name: 'Báo cáo bán hàng',
        channelType: 'chat',
        isZaloOAChannel: true,
      );

      expect(ch.isZaloOA, isTrue);
      expect(ch.isZaloPersonal, isFalse);
      expect(ch.effectiveCategory, equals('zalo_oa'));
    });

    test('Case 5: Channel with isZaloPersonalChannel distinguishes from OA', () {
      const ch = ChatV2Channel(
        id: '205',
        name: 'Tu van vien Tran C',
        channelType: 'chat',
        isZaloPersonalChannel: true,
      );

      expect(ch.isZaloPersonal, isTrue);
      expect(ch.isZaloOA, isFalse);
      expect(ch.effectiveCategory, equals('zalo'));
    });

    test('Case 6: Fallback for Livechat / CSKH when category is omitted', () {
      const ch = ChatV2Channel(
        id: '206',
        name: 'Hỗ trợ khách hàng Website',
        channelType: 'livechat',
      );

      expect(ch.effectiveCategory, equals('livechat'));
      expect(ch.effectiveCategoryLabel, equals('Hỗ trợ'));
      expect(ch.isSupportChannel, isTrue);
    });

    test('Case 7: Fallback for Discussion Channel & Group when category is omitted', () {
      const chChannel = ChatV2Channel(
        id: '207',
        name: 'Kênh Thông Báo Toàn Công Ty',
        channelType: 'channel',
      );
      const chGroup = ChatV2Channel(
        id: '208',
        name: 'Nhóm Triển Khai Odoo 19',
        channelType: 'group',
        isGroup: true,
      );

      expect(chChannel.effectiveCategory, equals('channel'));
      expect(chChannel.effectiveCategoryLabel, equals('Kênh'));
      expect(chGroup.effectiveCategory, equals('channel'));
      expect(chGroup.effectiveCategoryLabel, equals('Kênh'));
    });

    test('Case 8: Fallback for 1-1 Direct Chat when category is omitted', () {
      const ch = ChatV2Channel(
        id: '209',
        name: 'Le Ba Chau',
        channelType: 'chat',
      );

      expect(ch.effectiveCategory, equals('chat'));
      expect(ch.effectiveCategoryLabel, equals('Trò chuyện'));
    });

    test('Case 9: fromMap correctly parses backend JSON payload with category metadata', () {
      final json = {
        'id': 210,
        'name': 'Zalo OA Doanh Nghiep',
        'channel_type': 'zalo_oa',
        'category': 'zalo_oa',
        'category_label': 'Zalo OA',
        'is_zalo_oa': true,
        'is_zalo_personal': false,
        'unread_counter': 3,
      };

      final ch = ChatV2Channel.fromMap(json);

      expect(ch.id, equals('210'));
      expect(ch.category, equals('zalo_oa'));
      expect(ch.categoryLabel, equals('Zalo OA'));
      expect(ch.isZaloOAChannel, isTrue);
      expect(ch.isZaloPersonalChannel, isFalse);
      expect(ch.unreadCount, equals(3));
      expect(ch.effectiveCategory, equals('zalo_oa'));
      expect(ch.effectiveCategoryLabel, equals('Zalo OA'));
    });

    test('Case 10: toMap and copyWith serialize and retain category metadata', () {
      const ch = ChatV2Channel(
        id: '211',
        name: 'Kênh Test',
        channelType: 'channel',
        category: 'custom_feed',
        categoryLabel: 'Bản tin',
        isZaloOAChannel: false,
        isZaloPersonalChannel: false,
      );

      final map = ch.toMap();
      expect(map['category'], equals('custom_feed'));
      expect(map['category_label'], equals('Bản tin'));

      final copied = ch.copyWith(name: 'Kênh Test Đã Đổi Tên');
      expect(copied.name, equals('Kênh Test Đã Đổi Tên'));
      expect(copied.category, equals('custom_feed'));
      expect(copied.categoryLabel, equals('Bản tin'));
    });

    test('Case 11: Dynamic category partitioning partitions mixed channels accurately', () {
      final channels = [
        const ChatV2Channel(id: '1', name: 'Direct 1-1', channelType: 'chat', category: 'chat', categoryLabel: 'Trò chuyện'),
        const ChatV2Channel(id: '2', name: 'Dev Channel', channelType: 'channel', category: 'channel', categoryLabel: 'Kênh'),
        const ChatV2Channel(id: '3', name: 'Zalo OA CSKH', channelType: 'zalo_oa', category: 'zalo_oa', categoryLabel: 'Zalo OA', isZaloOAChannel: true),
        const ChatV2Channel(id: '4', name: 'Zalo Tran D', channelType: 'zalo', category: 'zalo', categoryLabel: 'Zalo', isZaloPersonalChannel: true),
        const ChatV2Channel(id: '5', name: 'Website Helpdesk', channelType: 'livechat', category: 'livechat', categoryLabel: 'Hỗ trợ'),
        const ChatV2Channel(id: '6', name: 'TikTok Shop Msg', channelType: 'tiktok', category: 'tiktok', categoryLabel: 'TikTok Shop'),
      ];

      final Map<String, int> categoryCounts = {};
      final Map<String, String> categoryLabels = {};
      for (final c in channels) {
        final cat = c.effectiveCategory;
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
        categoryLabels[cat] = c.effectiveCategoryLabel;
      }

      expect(categoryCounts['chat'], equals(1));
      expect(categoryCounts['channel'], equals(1));
      expect(categoryCounts['zalo_oa'], equals(1));
      expect(categoryCounts['zalo'], equals(1));
      expect(categoryCounts['livechat'], equals(1));
      expect(categoryCounts['tiktok'], equals(1));

      expect(categoryLabels['tiktok'], equals('TikTok Shop'));
    });
  });
}

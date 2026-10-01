import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

void main() {
  group('ChatV2Channel Odoo Discuss Channel Name Sanitization Tests', () {
    const currentUserName = 'Sếp Tân';

    // -------------------------------------------------------------------------
    // 1. BỐN KỊCH BẢN BẮT BUỘC THEO MASTER DIRECTIVE
    // -------------------------------------------------------------------------
    test('1.1. "Users + Internal / Ban Giám Đốc" bóc tách thành "Ban Giám Đốc"', () {
      const raw = 'Users + Internal / Ban Giám Đốc';
      final cleaned = ChatV2Channel.cleanChannelName(raw);
      expect(cleaned, equals('Ban Giám Đốc'));

      const channel = ChatV2Channel(id: '1', name: raw, channelType: 'channel', isGroup: true);
      expect(channel.displayName, equals('Ban Giám Đốc'));
      expect(channel.cleanName, equals('Ban Giám Đốc'));
      expect(channel.getCleanName(currentUserName), equals('Ban Giám Đốc'));
    });

    test('1.2. "(Users + Internal) Phòng Kỹ Thuật" bóc tách thành "Phòng Kỹ Thuật"', () {
      const raw = '(Users + Internal) Phòng Kỹ Thuật';
      final cleaned = ChatV2Channel.cleanChannelName(raw);
      expect(cleaned, equals('Phòng Kỹ Thuật'));

      const channel = ChatV2Channel(id: '2', name: raw, channelType: 'channel', isGroup: true);
      expect(channel.displayName, equals('Phòng Kỹ Thuật'));
      expect(channel.cleanName, equals('Phòng Kỹ Thuật'));
      expect(channel.getCleanName(currentUserName), equals('Phòng Kỹ Thuật'));
    });

    test('1.3. "Users / Dịch Vụ Khách Hàng" bóc tách thành "Dịch Vụ Khách Hàng"', () {
      const raw = 'Users / Dịch Vụ Khách Hàng';
      final cleaned = ChatV2Channel.cleanChannelName(raw);
      expect(cleaned, equals('Dịch Vụ Khách Hàng'));

      const channel = ChatV2Channel(id: '3', name: raw, channelType: 'channel', isGroup: true);
      expect(channel.displayName, equals('Dịch Vụ Khách Hàng'));
      expect(channel.cleanName, equals('Dịch Vụ Khách Hàng'));
      expect(channel.getCleanName(currentUserName), equals('Dịch Vụ Khách Hàng'));
    });

    test('1.4. "Users - Kinh Doanh" bóc tách thành "Kinh Doanh"', () {
      const raw = 'Users - Kinh Doanh';
      final cleaned = ChatV2Channel.cleanChannelName(raw);
      expect(cleaned, equals('Kinh Doanh'));

      const channel = ChatV2Channel(id: '4', name: raw, channelType: 'channel', isGroup: true);
      expect(channel.displayName, equals('Kinh Doanh'));
      expect(channel.cleanName, equals('Kinh Doanh'));
      expect(channel.getCleanName(currentUserName), equals('Kinh Doanh'));
    });

    // -------------------------------------------------------------------------
    // 2. CÁC BIẾN THỂ ODOO 17 & 19 MỞ RỘNG
    // -------------------------------------------------------------------------
    test('2.1. Tiền tố "Users +" và "Users + Internal -"', () {
      expect(ChatV2Channel.cleanChannelName('Users + Kinh Doanh'), equals('Kinh Doanh'));
      expect(ChatV2Channel.cleanChannelName('Users + Internal - General'), equals('General'));
      expect(ChatV2Channel.cleanChannelName('Users / Internal / Ban Giám Đốc'), equals('Ban Giám Đốc'));
    });

    test('2.2. Hậu tố "(Users + Internal)", "[Users + Internal]", "+ Internal", "- Internal"', () {
      expect(ChatV2Channel.cleanChannelName('Ban Giám Đốc (Users + Internal)'), equals('Ban Giám Đốc'));
      expect(ChatV2Channel.cleanChannelName('Thông Báo Nội Bộ [Users + Internal]'), equals('Thông Báo Nội Bộ'));
      expect(ChatV2Channel.cleanChannelName('Phòng Nhân Sự + Internal'), equals('Phòng Nhân Sự'));
      expect(ChatV2Channel.cleanChannelName('Hỗ Trợ - Internal'), equals('Hỗ Trợ'));
    });

    test('2.3. Biến thể độc lập chỉ gồm Users & Internal', () {
      expect(ChatV2Channel.cleanChannelName('Users + Internal'), equals('Internal'));
      expect(ChatV2Channel.cleanChannelName('users + internal'), equals('Internal'));
      expect(ChatV2Channel.cleanChannelName('USERS + INTERNAL'), equals('Internal'));
      expect(ChatV2Channel.cleanChannelName('Users/Internal'), equals('Internal'));
      expect(ChatV2Channel.cleanChannelName('Users - Internal'), equals('Internal'));
      expect(ChatV2Channel.cleanChannelName('(Users + Internal)'), equals('Internal'));
      expect(ChatV2Channel.cleanChannelName('[Users + Internal]'), equals('Internal'));
      expect(ChatV2Channel.cleanChannelName('Users + Internal / '), equals('Internal'));
      expect(ChatV2Channel.cleanChannelName('Internal'), equals('Internal'));
    });

    test('2.4. Xử lý khoảng trắng thừa, Unicode tabs, ký tự phân cách thừa', () {
      expect(ChatV2Channel.cleanChannelName('   Users   +   Internal   /   Ban Giám Đốc   '), equals('Ban Giám Đốc'));
      expect(ChatV2Channel.cleanChannelName('/ Users / Marketing /'), equals('Marketing'));
      expect(ChatV2Channel.cleanChannelName('- Users - Kế Toán -'), equals('Kế Toán'));
    });

    test('2.5. Fallback an toàn khi chuỗi rỗng', () {
      expect(ChatV2Channel.cleanChannelName(''), equals('Cuộc trò chuyện'));
      expect(ChatV2Channel.cleanChannelName('   '), equals('Cuộc trò chuyện'));
    });

    // -------------------------------------------------------------------------
    // 3. KIỂM THỬ DESERIALIZATION TỪ API VÀ LOCAL CACHE
    // -------------------------------------------------------------------------
    test('3.1. fromJson tự động làm sạch chuỗi rác từ field "name"', () {
      final json = {
        'id': 501,
        'name': 'Users + Internal / Ban Giám Đốc',
        'channel_type': 'channel',
        'is_group': true,
      };

      final channel = ChatV2Channel.fromJson(json);
      expect(channel.name, equals('Ban Giám Đốc'));
      expect(channel.displayName, equals('Ban Giám Đốc'));
      expect(channel.cleanName, equals('Ban Giám Đốc'));
    });

    test('3.2. fromJson tự động làm sạch chuỗi rác từ field "display_name"', () {
      final json = {
        'id': 502,
        'name': 'General',
        'display_name': '(Users + Internal) Phòng Kỹ Thuật',
        'channel_type': 'channel',
        'is_group': true,
      };

      final channel = ChatV2Channel.fromJson(json);
      expect(channel.name, equals('Phòng Kỹ Thuật'));
      expect(channel.displayName, equals('Phòng Kỹ Thuật'));
    });

    test('3.3. Dữ liệu từ Disk Cache nạp lên RAM được tự động làm sạch', () {
      final legacyDiskCacheMap = {
        'id': '503',
        'name': 'Users / Dịch Vụ Khách Hàng',
        'channel_type': 'channel',
        'is_group': true,
        'member_count': 5,
      };

      final channel = ChatV2Channel.fromMap(legacyDiskCacheMap);
      expect(channel.name, equals('Dịch Vụ Khách Hàng'));
      expect(channel.displayName, equals('Dịch Vụ Khách Hàng'));
    });

    test('3.4. ChatV2ChannelLocalCache.set lưu trữ và cung cấp danh sách kênh đã được làm sạch', () {
      final rawChannel = ChatV2Channel(
        id: '504',
        name: ChatV2Channel.cleanChannelName('Users - Kinh Doanh'),
        channelType: 'channel',
        isGroup: true,
      );

      ChatV2ChannelLocalCache.set([rawChannel]);
      final cached = ChatV2ChannelLocalCache.cached.firstWhere((c) => c.id == '504');

      expect(cached.name, equals('Kinh Doanh'));
      expect(cached.displayName, equals('Kinh Doanh'));
      expect(cached.cleanName, equals('Kinh Doanh'));
    });

    // -------------------------------------------------------------------------
    // 4. KIỂM THỬ ĐẶC TRỊ: "Chau, Le Ba (Internal)" & CHỐNG GHI ĐÈ CACHE
    // -------------------------------------------------------------------------
    test('4.1. cleanChannelName bóc tách "Chau, Le Ba (Internal)" thành "Internal"', () {
      const raw = 'Chau, Le Ba (Internal)';
      final cleaned = ChatV2Channel.cleanChannelName(raw);
      expect(cleaned, equals('Internal'));
    });

    test('4.2. cleanChannelName bóc tách các biến thể author push notification', () {
      expect(ChatV2Channel.cleanChannelName('Chau, Le Ba [Internal]'), equals('Internal'));
      expect(ChatV2Channel.cleanChannelName('Le Ba Chau (Internal)'), equals('Internal'));
      expect(ChatV2Channel.cleanChannelName('Internal / Chau, Le Ba'), equals('Internal'));
      expect(ChatV2Channel.cleanChannelName('Internal - Chau, Le Ba'), equals('Internal'));
    });

    test('4.3. Kênh nhóm Odoo (ID 4253) với tên dính push title hiển thị chuẩn "Internal"', () {
      const channel = ChatV2Channel(
        id: '4253',
        name: 'Chau, Le Ba (Internal)',
        channelType: 'channel',
        isGroup: true,
      );
      expect(channel.displayName, equals('Internal'));
      expect(channel.cleanName, equals('Internal'));
      expect(channel.getCleanName(currentUserName), equals('Internal'));
    });

    test('4.4. Kênh chat 1-1 nếu dính đuôi "(Internal)" chỉ hiển thị tên người chat', () {
      const channel = ChatV2Channel(
        id: '4244',
        name: 'Chau, Le Ba (Internal)',
        channelType: 'chat',
        isGroup: false,
      );
      expect(channel.getCleanName(currentUserName), equals('Chau, Le Ba'));
    });

    test('4.5. ChatV2ChannelLocalCache.set chống ghi đè cache và tự động dọn dẹp rác pinned', () {
      // Giả lập rác trong pinned direct channels
      const dirtyPinnedChannel = ChatV2Channel(
        id: '4253',
        name: 'Chau, Le Ba (Internal)',
        channelType: 'chat',
        isGroup: false,
      );
      ChatV2ChannelLocalCache.pinDirectChannel(dirtyPinnedChannel);

      // Kênh nhóm thật từ API Odoo
      const apiChannel = ChatV2Channel(
        id: '4253',
        name: 'Internal',
        channelType: 'group',
        isGroup: true,
      );

      // Gọi set với dữ liệu API
      ChatV2ChannelLocalCache.set([apiChannel]);

      // 1. Tên kênh trong cached BẮT BUỘC là "Internal", không bị đè bởi pinned cache
      final channelInCache = ChatV2ChannelLocalCache.cached.firstWhere((c) => c.id == '4253');
      expect(channelInCache.name, equals('Internal'));
      expect(channelInCache.displayName, equals('Internal'));

      // 2. Kênh nhóm ID 4253 BẮT BUỘC bị xóa khỏi pinned direct channels
      expect(ChatV2ChannelLocalCache.getPinnedDirectChannel('4253'), isNull);
    });

    test('4.6. pinDirectChannel từ chối lưu Group Channel hoặc kênh "Internal"', () {
      const groupChannel = ChatV2Channel(
        id: '4253',
        name: 'Internal',
        channelType: 'group',
        isGroup: true,
      );
      ChatV2ChannelLocalCache.pinDirectChannel(groupChannel);
      expect(ChatV2ChannelLocalCache.getPinnedDirectChannel('4253'), isNull);
    });

    test('4.7. fromJson tự động nhận diện kênh "Internal" là isGroup = true', () {
      final json = {
        'id': 4253,
        'name': 'Internal',
        'channel_type': 'group',
        'is_group': false, // Giả lập trường hợp API hoặc cache cũ lưu sai
      };
      final ch = ChatV2Channel.fromJson(json);
      expect(ch.isGroup, isTrue);
      expect(ch.name, equals('Internal'));
      expect(ch.displayName, equals('Internal'));
    });
  });
}

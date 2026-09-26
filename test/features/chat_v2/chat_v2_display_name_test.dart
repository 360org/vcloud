import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';

void main() {
  group('ChatV2Channel Display Name Resolution & Mapping Tests', () {
    const currentUserName = 'Sếp Tân';

    test('1. Kênh thảo luận Odoo (channelType == "channel") luôn giữ nguyên 100% tên kênh gốc ("Internal")', () {
      const channel = ChatV2Channel(
        id: '101',
        name: 'Internal',
        channelType: 'channel',
        isGroup: true,
        directPartnerName: 'Nguyễn Hoàng Khang',
        memberCount: 2,
      );

      final cleanName = channel.getCleanName(currentUserName);
      expect(cleanName, equals('Internal'));
    });

    test('2. Kênh Internal không có participant name vẫn hiển thị chuẩn xác tên kênh', () {
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

    test('3. Chat 1-1 trực tiếp với định dạng tên ghép bằng dấu phẩy bóc tách đúng người đối diện', () {
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

    test('4. Chat 1-1 trực tiếp khi tên kênh đã là tên người đối diện giữ nguyên tên người đó', () {
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

    test('5. Kênh nhóm nhiều người (group) giữ nguyên tên nhóm, không ghép tên thành viên vào title', () {
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

    test('6. Kênh thảo luận có tên cụ thể (như "Hỗ trợ khách hàng") luôn giữ nguyên tên kênh', () {
      const channel = ChatV2Channel(
        id: '106',
        name: 'Hỗ trợ khách hàng',
        channelType: 'channel',
        isGroup: true,
        directPartnerName: 'Lê Văn B',
        memberCount: 2,
      );

      final cleanName = channel.getCleanName(currentUserName);
      expect(cleanName, equals('Hỗ trợ khách hàng'));
    });

    test('7. Kênh Internal với danh sách members không bao giờ biến đổi title thành tên member', () {
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
      expect(cleanName, equals('Internal'));
    });

    test('8. Tên kênh rỗng fallback an toàn về nhãn mặc định', () {
      const channel = ChatV2Channel(
        id: '108',
        name: '',
        channelType: 'chat',
      );

      final cleanName = channel.getCleanName(currentUserName);
      expect(cleanName, equals('Cuộc trò chuyện'));
    });

    test('9. CurrentUserName null hoặc rỗng fallback về tên gốc của kênh', () {
      const channel = ChatV2Channel(
        id: '109',
        name: 'Internal',
        channelType: 'channel',
      );

      expect(channel.getCleanName(null), equals('Internal'));
      expect(channel.getCleanName('   '), equals('Internal'));
    });

    test('10. ChatV2Channel.fromJson cho kênh channelType == "channel" không gán directPartnerName gây biến dạng title', () {
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
      expect(parsed.name, equals('Internal'));
      expect(parsed.channelType, equals('channel'));
      expect(parsed.isChannel, isTrue);
      expect(parsed.directPartnerName, isNull);
      expect(parsed.getCleanName(currentUserName), equals('Internal'));
    });

    test('11. [Multi-Sender TDD] Kênh Internal khi nhận tin nhắn liên tục từ nhiều thành viên khác nhau vẫn giữ nguyên Title "Internal"', () {
      // Thiết lập kênh Internal ban đầu trong Cache
      final initialChannel = ChatV2Channel(
        id: '201',
        name: 'Internal',
        channelType: 'channel',
        isGroup: true,
        memberCount: 5,
        lastMessage: 'Khởi tạo kênh',
        lastMessageDate: DateTime.now().subtract(const Duration(hours: 2)),
      );

      ChatV2ChannelLocalCache.set([initialChannel]);

      // 1. Thành viên 1: Chau, Le Ba gửi tin nhắn
      ChatV2ChannelLocalCache.updateChannelLastMessage(
        '201',
        lastMessage: 'Chào mọi người, dự án đã bắt đầu',
        lastMessageDate: DateTime.now().subtract(const Duration(minutes: 30)),
        authorId: '10',
        authorName: 'Chau, Le Ba',
      );

      var cachedList = ChatV2ChannelLocalCache.cached;
      var currentCh = cachedList.firstWhere((c) => c.id == '201');
      expect(currentCh.name, equals('Internal'));
      expect(currentCh.getCleanName(currentUserName), equals('Internal'),
          reason: 'Title BẮT BUỘC giữ nguyên "Internal", KHÔNG ĐƯỢC biến thành "Chau, Le Ba (Internal)"');
      expect(currentCh.lastMessageAuthorName, equals('Chau, Le Ba'));

      // 2. Thành viên 2: Nguyen Thi Thu Thao gửi tin nhắn mới
      ChatV2ChannelLocalCache.updateChannelLastMessage(
        '201',
        lastMessage: 'Em đã nộp báo cáo tuần nhé',
        lastMessageDate: DateTime.now().subtract(const Duration(minutes: 10)),
        authorId: '11',
        authorName: 'Nguyen Thi Thu Thao',
      );

      cachedList = ChatV2ChannelLocalCache.cached;
      currentCh = cachedList.firstWhere((c) => c.id == '201');
      expect(currentCh.name, equals('Internal'));
      expect(currentCh.getCleanName(currentUserName), equals('Internal'),
          reason: 'Title BẮT BUỘC giữ nguyên "Internal", KHÔNG ĐƯỢC biến thành "Nguyen Thi Thu Thao (Internal)"');
      expect(currentCh.lastMessageAuthorName, equals('Nguyen Thi Thu Thao'));

      // 3. Thành viên 3: Sếp Tân (chính mình) gửi tin nhắn
      ChatV2ChannelLocalCache.updateChannelLastMessage(
        '201',
        lastMessage: 'Ok em, duyệt báo cáo nhé',
        lastMessageDate: DateTime.now(),
        authorId: '1',
        authorName: 'Sếp Tân',
      );

      cachedList = ChatV2ChannelLocalCache.cached;
      currentCh = cachedList.firstWhere((c) => c.id == '201');
      expect(currentCh.name, equals('Internal'));
      expect(currentCh.getCleanName(currentUserName), equals('Internal'));
      expect(currentCh.lastMessageAuthorName, equals('Sếp Tân'));
    });
  });
}

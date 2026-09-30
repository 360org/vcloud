import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

void main() {
  group('ChatV2 Rename Group & 1-1 Nickname Unit Tests', () {
    const currentUserName = 'Sếp Tân';

    test('1. Group channel rename updates name and getCleanName reflects new name', () {
      const channel = ChatV2Channel(
        id: '201',
        name: 'Dự án Mobile Cũ',
        channelType: 'channel',
        isGroup: true,
        memberCount: 5,
      );

      final renamed = channel.copyWith(name: 'Dự án Vcloud V2');
      expect(renamed.name, equals('Dự án Vcloud V2'));
      expect(renamed.getCleanName(currentUserName), equals('Dự án Vcloud V2'));
      expect(renamed.displayName, equals('Dự án Vcloud V2'));
    });

    test('2. Group channel rename cleans Odoo garbage prefixes if present', () {
      const channel = ChatV2Channel(
        id: '202',
        name: 'Nhóm',
        channelType: 'group',
        isGroup: true,
        memberCount: 4,
      );

      final renamed = channel.copyWith(name: 'Users + Internal / Ban Kỹ Thuật');
      expect(renamed.getCleanName(currentUserName), equals('Ban Kỹ Thuật'));
    });

    test('3. 1-1 Direct chat with customNickname prioritizes nickname in getCleanName', () {
      const channel = ChatV2Channel(
        id: '203',
        name: 'Nguyễn Văn A',
        channelType: 'chat',
        isGroup: false,
        directPartnerName: 'Nguyễn Văn A',
        memberCount: 2,
        customNickname: 'Đồng chí A Kỹ Thuật',
      );

      expect(channel.customNickname, equals('Đồng chí A Kỹ Thuật'));
      expect(channel.getCleanName(currentUserName), equals('Đồng chí A Kỹ Thuật'));
      expect(channel.displayName, equals('Đồng chí A Kỹ Thuật'));
    });

    test('4. 1-1 Direct chat without customNickname falls back to directPartnerName', () {
      const channel = ChatV2Channel(
        id: '204',
        name: 'Nguyễn Văn B',
        channelType: 'chat',
        isGroup: false,
        directPartnerName: 'Nguyễn Văn B',
        memberCount: 2,
      );

      expect(channel.customNickname, isNull);
      expect(channel.getCleanName(currentUserName), equals('Nguyễn Văn B'));
      expect(channel.displayName, equals('Nguyễn Văn B'));
    });

    test('5. 1-1 Direct chat with empty customNickname falls back to default clean name', () {
      const channel = ChatV2Channel(
        id: '205',
        name: 'Nguyễn Văn C',
        channelType: 'chat',
        isGroup: false,
        directPartnerName: 'Nguyễn Văn C',
        memberCount: 2,
        customNickname: '   ',
      );

      expect(channel.getCleanName(currentUserName), equals('Nguyễn Văn C'));
      expect(channel.displayName, equals('Nguyễn Văn C'));
    });

    test('6. ChatV2Channel toMap and fromJson round-trips customNickname correctly', () {
      const original = ChatV2Channel(
        id: '206',
        name: 'Trần Văn D',
        channelType: 'chat',
        isGroup: false,
        directPartnerName: 'Trần Văn D',
        customNickname: 'Anh D Quản Lý',
      );

      final map = original.toMap();
      expect(map['custom_nickname'], equals('Anh D Quản Lý'));

      final restored = ChatV2Channel.fromJson(map);
      expect(restored.id, equals('206'));
      expect(restored.customNickname, equals('Anh D Quản Lý'));
      expect(restored.getCleanName(currentUserName), equals('Anh D Quản Lý'));
    });

    test('7. ChatV2Channel.fromJson parses custom_channel_name from Odoo backend API', () {
      final apiPayload = {
        'id': '207',
        'name': 'Lê Thị E',
        'channel_type': 'chat',
        'is_group': false,
        'custom_channel_name': 'Chị E Kế Toán',
      };

      final channel = ChatV2Channel.fromJson(apiPayload);
      expect(channel.customNickname, equals('Chị E Kế Toán'));
      expect(channel.getCleanName(currentUserName), equals('Chị E Kế Toán'));
    });

    test('8. copyWith clearCustomNickname: true removes nickname cleanly', () {
      const channel = ChatV2Channel(
        id: '208',
        name: 'Hoàng F',
        channelType: 'chat',
        isGroup: false,
        directPartnerName: 'Hoàng F',
        customNickname: 'F Designer',
      );

      final cleared = channel.copyWith(clearCustomNickname: true);
      expect(cleared.customNickname, isNull);
      expect(cleared.getCleanName(currentUserName), equals('Hoàng F'));
    });

    test('9. Input validation: trim leading/trailing whitespace and empty check', () {
      String sanitizeInput(String input) => input.trim();
      bool isValidName(String input) {
        final trimmed = sanitizeInput(input);
        return trimmed.isNotEmpty && trimmed.length <= 100;
      }

      expect(isValidName(''), isFalse);
      expect(isValidName('   '), isFalse);
      expect(isValidName('\n\t  '), isFalse);
      expect(isValidName('Nhóm Dev Mobile'), isTrue);
      expect(isValidName('   Tên Cần Cắt Khoảng Trắng   '), isTrue);
      expect(sanitizeInput('   Tên Cần Cắt Khoảng Trắng   '), equals('Tên Cần Cắt Khoảng Trắng'));
    });

    test('10. Input validation: reject names exceeding 100 characters', () {
      bool isValidName(String input) {
        final trimmed = input.trim();
        return trimmed.isNotEmpty && trimmed.length <= 100;
      }

      final exact100 = 'A' * 100;
      final over100 = 'B' * 101;

      expect(isValidName(exact100), isTrue);
      expect(isValidName(over100), isFalse);
    });
  });
}

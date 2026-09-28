import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

void main() {
  group('BUG-018 & BUG-019: Zalo OA & isInternalDirect Filtering Tests', () {
    test('ChatV2Channel.fromJson parses is_zalo_channel properly', () {
      final json = {
        'id': '2250',
        'name': 'Minh Thuỳ Dương',
        'channel_type': 'group',
        'is_group': true,
        'is_zalo_channel': true,
        'member_count': 3,
        'last_message': 'Dạ vâng em cảm ơn',
      };

      final channel = ChatV2Channel.fromJson(json);
      expect(channel.id, '2250');
      expect(channel.isZaloChannel, isTrue);
      expect(channel.isZaloOA, isTrue);
    });

    test('897 Zalo OA channels with channel_type=group are excluded from Nhóm', () {
      final zaloChannel = ChatV2Channel.fromJson({
        'id': '897',
        'name': 'Khách hàng Zalo OA Lâm Hà',
        'channel_type': 'group',
        'is_group': true,
        'is_zalo_channel': true,
        'member_count': 4,
        'last_message': 'Tư vấn giúp em gói phần mềm',
      });

      // Phải là Zalo OA
      expect(zaloChannel.isZaloOA, isTrue);
      // getActualIsGroup và isGroupChat BẮT BUỘC return false để không lọt vào tab Nhóm
      expect(zaloChannel.getActualIsGroup('Ma Nguyễn Nhật Tân'), isFalse);
      expect(zaloChannel.isGroupChat('Ma Nguyễn Nhật Tân'), isFalse);
    });

    test('Zalo OA channel with @Ask AI bot message does NOT leak into Trực tiếp', () {
      final zaloChannelWithBot = ChatV2Channel.fromJson({
        'id': '2250',
        'name': 'Minh Thuỳ Dương',
        'channel_type': 'group',
        'is_group': true,
        'is_zalo_channel': true,
        'last_message': '@Ask AI: Tôi có thể giúp gì cho bạn?',
        'members': [
          {'id': '101', 'name': 'Minh Thuỳ Dương', 'email': 'duongmt@gmail.com'},
          {'id': '102', 'name': 'Ma Nguyễn Nhật Tân', 'email': 'tanmnn@360.org.vn', 'is_me': true},
        ],
      });

      // Vì là isZaloOA -> isInternalDirect BẮT BUỘC trả về false
      expect(zaloChannelWithBot.isZaloOA, isTrue);
      expect(zaloChannelWithBot.isInternalDirect('Ma Nguyễn Nhật Tân'), isFalse);
    });

    test('External customer 1-1 with bot message is excluded from isInternalDirect', () {
      final externalCustomerDirect = ChatV2Channel.fromJson({
        'id': '3301',
        'name': 'Khách Hàng Ngoài',
        'channel_type': 'chat',
        'is_group': false,
        'is_zalo_channel': false,
        'last_message': '@Ask AI: Xin chào quý khách!',
        'members': [
          {'id': '201', 'name': 'Khách Hàng Ngoài', 'email': 'khachhang@gmail.com'},
          {'id': '202', 'name': 'Nhân viên 360', 'email': 'nhanvien@360.org.vn', 'is_me': true},
        ],
      });

      // Domain ngoài gmail.com -> BẮT BUỘC return false kể cả khi last_message không rỗng
      expect(externalCustomerDirect.isInternalDirect('Nhân viên 360'), isFalse);
    });

    test('Internal company 1-1 chat passes isInternalDirect even with messages', () {
      final internalDirect = ChatV2Channel.fromJson({
        'id': '3302',
        'name': 'Nguyễn Văn B',
        'channel_type': 'chat',
        'is_group': false,
        'is_zalo_channel': false,
        'last_message': 'Đã nhận task nhé!',
        'members': [
          {'id': '301', 'name': 'Nguyễn Văn B', 'email': 'b.nguyen@360.org.vn'},
          {'id': '302', 'name': 'Ma Nguyễn Nhật Tân', 'email': 'tanmnn@360.org.vn', 'is_me': true},
        ],
      });

      expect(internalDirect.isInternalDirect('Ma Nguyễn Nhật Tân'), isTrue);
    });

    test('toMap and fromMap preserves is_zalo_channel round-trip', () {
      const ch = ChatV2Channel(
        id: '999',
        name: 'Zalo Test',
        channelType: 'chat',
        isZaloChannel: true,
      );

      final map = ch.toMap();
      expect(map['is_zalo_channel'], isTrue);

      final restored = ChatV2Channel.fromMap(map);
      expect(restored.isZaloChannel, isTrue);
      expect(restored.isZaloOA, isTrue);
    });
  });

  group('BUG-020: Member Roles & Leader Permissions Tests', () {
    test('ChatV2Member parses is_leader and admin roles correctly', () {
      final leaderMember = ChatV2Member.fromJson({
        'id': '10',
        'name': 'Trưởng nhóm A',
        'email': 'leader@360.org.vn',
        'is_leader': true,
      });
      expect(leaderMember.isLeader, isTrue);

      final regularMember = ChatV2Member.fromJson({
        'id': '11',
        'name': 'Thành viên B',
        'email': 'member@360.org.vn',
        'is_leader': false,
      });
      expect(regularMember.isLeader, isFalse);

      final adminMember = ChatV2Member.fromJson({
        'id': '12',
        'name': 'Quản trị viên C',
        'is_admin': true,
      });
      expect(adminMember.isLeader, isTrue);
    });

    test('ChatV2Member to/from JSON round-trip retains isLeader', () {
      const member = ChatV2Member(
        id: '55',
        name: 'Nguyễn Văn Leader',
        email: 'leader@360.org.vn',
        isLeader: true,
        isMe: true,
      );

      final json = member.toJson();
      expect(json['is_leader'], isTrue);

      final parsed = ChatV2Member.fromJson(json);
      expect(parsed.isLeader, isTrue);
    });
  });
}

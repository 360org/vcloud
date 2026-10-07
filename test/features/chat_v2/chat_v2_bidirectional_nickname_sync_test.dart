import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/data/odoo_bus_service.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';

void main() {
  group('Bidirectional Nickname Sync Contract (Web & Mobile) Tests', () {
    test('1. ChatV2Member parses custom_channel_name and nickname from Odoo JSON', () {
      final json = {
        'id': '101',
        'name': 'Nguyễn Văn Nam',
        'partner_id': 101,
        'custom_channel_name': 'Nam Dev Mobile',
        'nickname': 'Nam Dev Mobile',
        'im_status': 'online',
      };

      final member = ChatV2Member.fromJson(json);
      expect(member.id, equals('101'));
      expect(member.name, equals('Nguyễn Văn Nam'));
      expect(member.partnerId, equals(101));
      expect(member.customChannelName, equals('Nam Dev Mobile'));
      expect(member.nickname, equals('Nam Dev Mobile'));
      expect(member.displayName, equals('Nam Dev Mobile'));
    });

    test('2. ChatV2Member displayName falls back to name when nickname is null or empty', () {
      const memberWithoutNickname = ChatV2Member(
        id: '102',
        name: 'Trần Thị Mai',
        partnerId: 102,
      );
      expect(memberWithoutNickname.displayName, equals('Trần Thị Mai'));

      final memberWithEmptyNickname = memberWithoutNickname.copyWith(nickname: '   ');
      expect(memberWithEmptyNickname.displayName, equals('Trần Thị Mai'));
    });

    test('3. ChatV2Member copyWith updates nickname and clearNickname removes it', () {
      const original = ChatV2Member(
        id: '103',
        name: 'Lê Văn Cường',
        partnerId: 103,
      );

      final updated = original.copyWith(
        customChannelName: 'Anh Cường Tech Lead',
        nickname: 'Anh Cường Tech Lead',
      );
      expect(updated.displayName, equals('Anh Cường Tech Lead'));

      final cleared = updated.copyWith(clearNickname: true);
      expect(cleared.nickname, isNull);
      expect(cleared.customChannelName, isNull);
      expect(cleared.displayName, equals('Lê Văn Cường'));
    });

    test('4. ChatV2Member toJson encodes custom_channel_name, nickname, and partner_id', () {
      const member = ChatV2Member(
        id: '104',
        name: 'Phạm Hồng Đức',
        partnerId: 104,
        customChannelName: 'Đức QA',
        nickname: 'Đức QA',
      );

      final json = member.toJson();
      expect(json['id'], equals('104'));
      expect(json['name'], equals('Phạm Hồng Đức'));
      expect(json['partner_id'], equals(104));
      expect(json['custom_channel_name'], equals('Đức QA'));
      expect(json['nickname'], equals('Đức QA'));
    });

    test('5. OdooBusService processes discuss.channel.member/nickname_updated event', () async {
      final busService = OdooBusService();
      Map<String, dynamic>? received;

      final sub = busService.onNicknameNotification.listen((data) {
        received = data;
      });

      final busItem = {
        'type': 'discuss.channel.member/nickname_updated',
        'payload': {
          'channel_id': 99,
          'partner_id': 105,
          'member_id': 456,
          'nickname': 'Sếp Tân (Giám đốc)',
          'custom_channel_name': 'Sếp Tân (Giám đốc)',
        },
      };

      busService.processBusNotificationForTesting(busItem);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, isNotNull);
      expect(received!['channel_id'], equals(99));
      expect(received!['partner_id'], equals(105));
      expect(received!['member_id'], equals(456));
      expect(received!['nickname'], equals('Sếp Tân (Giám đốc)'));

      await sub.cancel();
      busService.dispose();
    });

    test('6. OdooBusService processes mail.record/insert with member nickname', () async {
      final busService = OdooBusService();
      Map<String, dynamic>? received;

      final sub = busService.onNicknameNotification.listen((data) {
        received = data;
      });

      final insertItem = {
        'type': 'mail.record/insert',
        'payload': {
          'discuss.channel.member': [
            {
              'id': 789,
              'channel_id': 100,
              'partner_id': 106,
              'custom_channel_name': 'Bạn Linh Marketing',
              'nickname': 'Bạn Linh Marketing',
            },
          ],
        },
      };

      busService.processBusNotificationForTesting(insertItem);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, isNotNull);
      expect(received!['channel_id'], equals(100));
      expect(received!['partner_id'], equals(106));
      expect(received!['nickname'], equals('Bạn Linh Marketing'));

      await sub.cancel();
      busService.dispose();
    });

    test('7. ChatV2Message copyWith authorName updates chat bubble author instantaneously', () {
      final message = ChatV2Message(
        id: 'msg_1',
        channelId: 'ch_1',
        content: 'Xin chào mọi người!',
        authorId: '107',
        authorName: 'Đặng Quốc Huy',
        createdAt: DateTime(2026, 10, 7, 10, 0),
        isMine: false,
      );

      final updatedMessage = message.copyWith(authorName: 'Huy Backend');
      expect(updatedMessage.authorName, equals('Huy Backend'));
      expect(updatedMessage.id, equals('msg_1'));
      expect(updatedMessage.content, equals('Xin chào mọi người!'));
      expect(updatedMessage.authorId, equals('107'));
    });

    test('8. ChatV2ChannelLocalCache setCustomNickname stores and updates local channel', () async {
      const channel = ChatV2Channel(
        id: '501',
        name: 'Trần Văn Hoàng',
        channelType: 'chat',
        isGroup: false,
        directPartnerName: 'Trần Văn Hoàng',
      );

      ChatV2ChannelLocalCache.set([channel]);

      await ChatV2ChannelLocalCache.setCustomNickname('501', 'Hoàng DevOps');

      expect(ChatV2ChannelLocalCache.getCustomNickname('501'), equals('Hoàng DevOps'));

      final cachedCh = ChatV2ChannelLocalCache.cached.firstWhere((c) => c.id == '501');
      expect(cachedCh.customNickname, equals('Hoàng DevOps'));
      expect(cachedCh.getCleanName('Tôi'), equals('Hoàng DevOps'));
    });

    test('9. ChatV2Channel customNickname takes precedence over directPartnerName in 1-1 chat', () {
      const channel = ChatV2Channel(
        id: '502',
        name: 'Ngô Thanh Vân',
        channelType: 'chat',
        isGroup: false,
        directPartnerName: 'Ngô Thanh Vân',
        customNickname: 'Vân Nhân Sự',
      );

      expect(channel.getCleanName('Bất kỳ ai'), equals('Vân Nhân Sự'));
    });

    test('10. ChatV2Channel copyWith members updates member nickname in list', () {
      const member1 = ChatV2Member(id: '1', name: 'User 1', partnerId: 1);
      const member2 = ChatV2Member(id: '2', name: 'User 2', partnerId: 2);
      const groupChannel = ChatV2Channel(
        id: '503',
        name: 'Phòng Kỹ Thuật',
        channelType: 'channel',
        isGroup: true,
        members: [member1, member2],
      );

      final updatedMembers = groupChannel.members.map((m) {
        if (m.partnerId == 2) {
          return m.copyWith(
            customChannelName: 'User 2 (Kỹ thuật viên)',
            nickname: 'User 2 (Kỹ thuật viên)',
          );
        }
        return m;
      }).toList();

      final updatedChannel = groupChannel.copyWith(members: updatedMembers);

      expect(updatedChannel.members.first.displayName, equals('User 1'));
      expect(updatedChannel.members.last.displayName, equals('User 2 (Kỹ thuật viên)'));
    });
  });
}

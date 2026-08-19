import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';

void main() {
  group('TASK #16446: Avatar Resolution & Prevention of Self-Avatar Leak', () {
    test('ChatV2Member.fromJson does not generate fake avatar URL when raw avatar is null', () {
      final json = {
        'id': '120',
        'name': 'Bùi Tuấn Kiệt',
        'avatar_url': null,
        'image_128': false,
      };

      final member = ChatV2Member.fromJson(json);
      expect(member.avatarUrl, isNull);
    });

    test('ChatV2Channel.fromJson does not fabricate avatar URL when other member has no avatar', () {
      final json = {
        'id': '115',
        'name': 'Bùi Tuấn Kiệt',
        'channel_type': 'chat',
        'is_group': false,
        'members': [
          {'id': '115', 'name': 'Ma Nguyễn Nhật Tân', 'is_me': true, 'avatar_url': 'https://vuahethong.net/cat.png'},
          {'id': '120', 'name': 'Bùi Tuấn Kiệt', 'is_me': false, 'avatar_url': null},
        ],
      };

      final channel = ChatV2Channel.fromJson(json);
      // Bùi Tuấn Kiệt không có avatar -> channel avatarUrl phải là null để hiển thị chữ 'B'
      expect(channel.avatarUrl, isNull);
    });
  });

  group('TASK #16447: Group Filter vs Channel Filter Logic', () {
    test('Channel with channel_type == "group" is classified as Group Chat', () {
      final groupChannel = ChatV2Channel(
        id: '201',
        name: 'Chuyển Nhà Trọn Gói',
        channelType: 'group',
        isGroup: true,
        memberCount: 5,
      );

      expect(groupChannel.isGroupChat('Ma Nguyễn Nhật Tân'), isTrue);
      expect(groupChannel.isInternalDirect('Ma Nguyễn Nhật Tân'), isFalse);
    });

    test('Channel with channel_type == "chat" is classified as Internal Direct', () {
      final directChannel = ChatV2Channel(
        id: '202',
        name: 'Bùi Tuấn Kiệt',
        channelType: 'chat',
        isGroup: false,
        memberCount: 2,
        directPartnerId: '120',
        directPartnerName: 'Bùi Tuấn Kiệt',
      );

      expect(directChannel.isInternalDirect('Ma Nguyễn Nhật Tân'), isTrue);
      expect(directChannel.isGroupChat('Ma Nguyễn Nhật Tân'), isFalse);
    });

    test('General announcement channel is classified as isChannel', () {
      final broadcastChannel = ChatV2Channel(
        id: '203',
        name: 'Thông Báo Toàn Công Ty',
        channelType: 'channel',
        isGroup: false,
        memberCount: 0,
      );

      expect(broadcastChannel.isChannel, isTrue);
    });
  });

  group('TASK #16448: Optimistic Message State & Error Elimination', () {
    test('sentMsg replaces tempId cleanly without duplicating or keeping error status', () {
      const tempId = 'temp_att_1724080000';
      const realId = '9999';

      final tempMsg = ChatV2Message(
        id: tempId,
        channelId: '115',
        content: '[Hình ảnh]',
        createdAt: DateTime.now(),
        isMine: true,
        status: 'pending',
      );

      final currentList = <ChatV2Message>[tempMsg];

      final sentMsg = ChatV2Message(
        id: realId,
        channelId: '115',
        content: '[Hình ảnh]',
        createdAt: DateTime.now(),
        isMine: true,
        status: 'sent',
      );

      // Mô phỏng logic cập nhật của controller
      final updatedList = currentList.toList();
      updatedList.removeWhere((m) => m.id == tempId || m.id == realId);
      updatedList.insert(0, sentMsg);

      expect(updatedList.length, 1);
      expect(updatedList.first.id, realId);
      expect(updatedList.first.status, 'sent');
      expect(updatedList.any((m) => m.id == tempId), isFalse);
    });
  });

  group('TASK #16449: Cache Fast-Path Navigation for Direct Chats', () {
    test('Local cache can instantly locate existing 1-1 conversation by partnerId', () {
      final ch1 = ChatV2Channel(
        id: '115',
        name: 'Bùi Tuấn Kiệt',
        channelType: 'chat',
        isGroup: false,
        directPartnerId: '120',
      );
      final ch2 = ChatV2Channel(
        id: '116',
        name: 'Lâm Á Thi',
        channelType: 'chat',
        isGroup: false,
        directPartnerId: '121',
      );

      final cached = [ch1, ch2];

      final found = cached.firstWhere(
        (c) => !c.isGroup && c.directPartnerId == '120',
      );

      expect(found.id, '115');
      expect(found.name, 'Bùi Tuấn Kiệt');
    });
  });
}

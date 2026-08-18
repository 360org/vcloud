import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatV2 Avatar Resolution Tests', () {
    test('1. ChatV2Channel resolves relative avatar_url to absolute URL', () {
      final channelMap = {
        'id': 4,
        'name': 'Mitchell Admin',
        'channel_type': 'chat',
        'avatar_url': '/api/v1/mobile/avatar/partners/3',
        'is_group': false,
      };

      final channel = ChatV2Channel.fromMap(channelMap);
      expect(channel.avatarUrl, isNotNull);
      expect(channel.avatarUrl, contains('/api/v1/mobile/avatar/partners/3'));
      expect(channel.avatarUrl, startsWith('http'));
    });

    test('2. ChatV2Channel 1-1 chat falls back to direct_partner avatar if channel avatar is null', () {
      final channelMap = {
        'id': 6,
        'name': 'OdooBot',
        'channel_type': 'chat',
        'is_group': false,
        'direct_partner': {
          'id': 2,
          'name': 'OdooBot',
          'avatar_url': '/web/image/res.partner/2/avatar_128',
        },
      };

      final channel = ChatV2Channel.fromMap(channelMap);
      expect(channel.avatarUrl, isNotNull);
      expect(channel.avatarUrl, contains('/web/image/res.partner/2/avatar_128'));
      expect(channel.avatarUrl, startsWith('http'));
    });

    test('3. ChatV2Member resolves avatar_url into absolute URL', () {
      final memberMap = {
        'id': 3,
        'name': 'Mitchell Admin',
        'avatar_url': '/web/image/res.partner/3/avatar_128',
      };

      final member = ChatV2Member.fromJson(memberMap);
      expect(member.avatarUrl, isNotNull);
      expect(member.avatarUrl, contains('/web/image/res.partner/3/avatar_128'));
      expect(member.avatarUrl, startsWith('http'));
    });

    test('4. ChatV2Message resolves author_avatar into absolute URL', () {
      final messageMap = {
        'id': 101,
        'channel_id': 4,
        'body': 'Hello world',
        'author_id': 3,
        'author_name': 'Mitchell Admin',
        'author_avatar': '/web/image/res.partner/3/avatar_128',
      };

      final message = ChatV2Message.fromMap(messageMap);
      expect(message.authorAvatar, isNotNull);
      expect(message.authorAvatar, contains('/web/image/res.partner/3/avatar_128'));
      expect(message.authorAvatar, startsWith('http'));
    });
  });
}

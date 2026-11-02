import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_info_sheet.dart';

void main() {
  group('ChatV2 Group Avatar Unit Tests (10 Independent Cases)', () {
    const channelId = '105';
    const groupName = 'Nhóm Phát Triển Vcloud';

    test('1. ChatV2Channel model avatarUrl correctly retains and reads network URL', () {
      const channel = ChatV2Channel(
        id: channelId,
        name: groupName,
        channelType: 'group',
        isGroup: true,
        avatarUrl: '/web/image/discuss.channel/105/image_128',
      );
      expect(channel.avatarUrl, equals('/web/image/discuss.channel/105/image_128'));
      expect(channel.isGroup, isTrue);
    });

    test('2. ChatV2Channel copyWith updates avatarUrl correctly', () {
      const channel = ChatV2Channel(
        id: channelId,
        name: groupName,
        channelType: 'group',
        isGroup: true,
        avatarUrl: null,
      );
      final updated = channel.copyWith(avatarUrl: '/web/image/discuss.channel/105/avatar_128?unique=123');
      expect(updated.avatarUrl, equals('/web/image/discuss.channel/105/avatar_128?unique=123'));
    });

    test('3. ChatV2Channel copyWith clears avatarUrl when passed empty or null', () {
      const channel = ChatV2Channel(
        id: channelId,
        name: groupName,
        channelType: 'group',
        isGroup: true,
        avatarUrl: '/web/image/discuss.channel/105/avatar_128',
      );
      final cleared = channel.copyWith(avatarUrl: null, clearAvatar: true);
      expect(cleared.avatarUrl, isNull);
    });

    test('4. ChatV2ChannelLocalCache stores and retrieves updated group avatar', () {
      const channel = ChatV2Channel(
        id: channelId,
        name: groupName,
        channelType: 'group',
        isGroup: true,
      );
      ChatV2ChannelLocalCache.set([channel]);
      expect(ChatV2ChannelLocalCache.cached.first.avatarUrl, isNull);

      final updated = channel.copyWith(avatarUrl: '/web/image/discuss.channel/105/avatar_128?v=1');
      ChatV2ChannelLocalCache.updateChannel(updated);
      expect(ChatV2ChannelLocalCache.cached.first.avatarUrl, equals('/web/image/discuss.channel/105/avatar_128?v=1'));
    });

    test('5. ChatV2ChannelLocalCache clearing avatar resets to null safely', () {
      const channel = ChatV2Channel(
        id: channelId,
        name: groupName,
        channelType: 'group',
        isGroup: true,
        avatarUrl: '/web/image/discuss.channel/105/avatar_128?v=1',
      );
      ChatV2ChannelLocalCache.set([channel]);
      expect(ChatV2ChannelLocalCache.cached.first.avatarUrl, isNotNull);

      final cleared = channel.copyWith(avatarUrl: null, clearAvatar: true);
      ChatV2ChannelLocalCache.updateChannel(cleared);
      expect(ChatV2ChannelLocalCache.cached.first.avatarUrl, isNull);
    });

    test('6. ChatV2InfoSheet.getAvatarGradient produces valid deterministic gradients', () {
      final grad1 = ChatV2InfoSheet.getAvatarGradient('Nhóm A');
      final grad2 = ChatV2InfoSheet.getAvatarGradient('Nhóm A');
      final grad3 = ChatV2InfoSheet.getAvatarGradient('Nhóm B');

      expect(grad1.length, equals(2));
      expect(grad1[0], equals(grad2[0]));
      expect(grad1[1], equals(grad2[1]));
      expect(grad1, isNotNull);
      expect(grad3, isNotNull);
    });

    test('7. ChatV2InfoSheet.getAvatarGradient handles empty string safely without crash', () {
      final grad = ChatV2InfoSheet.getAvatarGradient('');
      expect(grad.length, equals(2));
      expect(grad, equals(ChatV2InfoSheet.getAvatarGradient('')));
    });

    test('8. ChatV2InfoSheet.getInitial generates 2-letter initials for multi-word groups', () {
      expect(ChatV2InfoSheet.getInitial('Nhóm Phát Triển'), equals('NT'));
      expect(ChatV2InfoSheet.getInitial('Ban Kỹ Thuật'), equals('BT'));
      expect(ChatV2InfoSheet.getInitial('Vcloud 2026'), equals('V2'));
    });

    test('9. ChatV2InfoSheet.getInitial generates 1-letter initial for single word groups', () {
      expect(ChatV2InfoSheet.getInitial('General'), equals('G'));
      expect(ChatV2InfoSheet.getInitial('vcloud'), equals('V'));
    });

    test('10. ChatV2InfoSheet.getInitial handles empty and whitespace safely', () {
      expect(ChatV2InfoSheet.getInitial(''), equals('U'));
      expect(ChatV2InfoSheet.getInitial('   '), equals('U'));
    });
  });
}

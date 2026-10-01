import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

void main() {
  group('ChatV2 Channel Share Link & UUID Tests', () {
    test('1. Channel with valid invitation_url returns existing invitation_url', () {
      const channel = ChatV2Channel(
        id: '101',
        name: 'Group A',
        channelType: 'group',
        isGroup: true,
        uuid: 'test-uuid-123',
        invitationUrl: 'https://vuahethong.net/chat/101/test-uuid-123',
      );
      expect(channel.invitationUrl, 'https://vuahethong.net/chat/101/test-uuid-123');
      expect(channel.uuid, 'test-uuid-123');
    });

    test('2. Channel with null invitation_url but valid uuid can construct link', () {
      const channel = ChatV2Channel(
        id: '102',
        name: 'Group B',
        channelType: 'group',
        isGroup: true,
        uuid: 'generated-uuid-456',
        invitationUrl: null,
      );
      final constructedUrl = '/chat/${channel.id}/${channel.uuid}';
      expect(constructedUrl, '/chat/102/generated-uuid-456');
    });

    test('3. Channel with null uuid and null invitation_url identifies as missing link', () {
      const channel = ChatV2Channel(
        id: '103',
        name: 'Group C',
        channelType: 'group',
        isGroup: true,
        uuid: null,
        invitationUrl: null,
      );
      final hasLink = (channel.invitationUrl != null && channel.invitationUrl!.isNotEmpty) ||
          (channel.uuid != null && channel.uuid!.isNotEmpty);
      expect(hasLink, false);
    });

    test('4. Channel copyWith correctly updates uuid and invitationUrl after lazy fetch', () {
      const oldChannel = ChatV2Channel(
        id: '104',
        name: 'Group D',
        channelType: 'group',
        isGroup: true,
        uuid: null,
        invitationUrl: null,
      );
      final updatedChannel = oldChannel.copyWith(
        uuid: 'new-lazy-uuid-789',
        invitationUrl: 'https://vuahethong.net/chat/104/new-lazy-uuid-789',
      );
      expect(updatedChannel.uuid, 'new-lazy-uuid-789');
      expect(updatedChannel.invitationUrl, 'https://vuahethong.net/chat/104/new-lazy-uuid-789');
      expect(updatedChannel.id, '104');
      expect(updatedChannel.name, 'Group D');
    });

    test('5. Channel JSON deserialization handles null uuid safely', () {
      final json = {
        'id': 105,
        'name': 'Channel Null UUID',
        'channel_type': 'channel',
        'uuid': null,
        'invitation_url': null,
      };
      final ch = ChatV2Channel.fromJson(json);
      expect(ch.id, '105');
      expect(ch.uuid, isNull);
      expect(ch.invitationUrl, isNull);
    });

    test('6. Channel JSON deserialization parses valid uuid and invitation_url', () {
      final json = {
        'id': 106,
        'name': 'Channel Valid UUID',
        'channel_type': 'channel',
        'uuid': 'sample-uuid-001',
        'invitation_url': 'https://vuahethong.net/chat/106/sample-uuid-001',
      };
      final ch = ChatV2Channel.fromJson(json);
      expect(ch.id, '106');
      expect(ch.uuid, 'sample-uuid-001');
      expect(ch.invitationUrl, 'https://vuahethong.net/chat/106/sample-uuid-001');
    });

    test('7. Relative invitation_url formatted properly with base path', () {
      const relPath = '/chat/107/sample-uuid-002';
      const baseUrl = 'https://vuahethong.net';
      const fullUrl = '$baseUrl$relPath';
      expect(fullUrl, 'https://vuahethong.net/chat/107/sample-uuid-002');
    });

    test('8. Channel type chat vs group link representation', () {
      const chatChannel = ChatV2Channel(id: '108', name: 'Direct', channelType: 'chat', isGroup: false, uuid: 'u1');
      const groupChannel = ChatV2Channel(id: '109', name: 'Group', channelType: 'group', isGroup: true, uuid: 'u2');
      expect(chatChannel.isGroup, false);
      expect(groupChannel.isGroup, true);
      expect('/chat/${chatChannel.id}/${chatChannel.uuid}', '/chat/108/u1');
      expect('/chat/${groupChannel.id}/${groupChannel.uuid}', '/chat/109/u2');
    });

    test('9. Whitespace-only uuid or invitation_url treated as empty/invalid', () {
      const ch = ChatV2Channel(
        id: '110',
        name: 'Space Channel',
        channelType: 'group',
        uuid: '   ',
        invitationUrl: '   ',
      );
      final isValidUuid = ch.uuid != null && ch.uuid!.trim().isNotEmpty;
      final isValidInv = ch.invitationUrl != null && ch.invitationUrl!.trim().isNotEmpty;
      expect(isValidUuid, false);
      expect(isValidInv, false);
    });

    test('10. Ensure UUID match regex format (v4 hex pattern)', () {
      const sampleUuid = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';
      final uuidRegExp = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      expect(uuidRegExp.hasMatch(sampleUuid), true);
    });
  });
}

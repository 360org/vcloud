import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_input_bar.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

void main() {
  group('ChatV2 Models Parsing', () {
    test('ChatV2Channel parses Odoo channel JSON correctly', () {
      final json = {
        'id': 4255,
        'name': 'Bùi Tuấn Kiệt',
        'channel_type': 'chat',
        'is_group': false,
        'avatar_url': 'https://vuahethong.net/web/image/res.partner/123/avatar_128',
        'last_message': {
          'body': '<p>Xin chào anh Tân!</p>',
          'date': '2026-08-14T03:00:00Z',
        },
        'unread_count': 3,
        'members': [
          {'id': 1, 'name': 'Bùi Tuấn Kiệt'},
          {'id': 2, 'name': 'Tân Ma'},
        ],
      };

      final channel = ChatV2Channel.fromMap(json);

      expect(channel.id, '4255');
      expect(channel.name, 'Bùi Tuấn Kiệt');
      expect(channel.isGroup, false);
      expect(channel.lastMessage, 'Xin chào anh Tân!');
      expect(channel.unreadCount, 3);
      expect(channel.memberNames, contains('Bùi Tuấn Kiệt'));
      expect(channel.memberNames, contains('Tân Ma'));
    });

    test('ChatV2Attachment parses attachment JSON correctly and detects isImage', () {
      final json = {
        'id': 1064,
        'name': 'photo.png',
        'mimetype': 'image/png',
        'file_size': 2048,
        'url': 'https://vuahethong.net/web/content/1064/photo.png?access_token=xyz',
        'download_url': '/api/v1/mobile/attachments/1064/download?access_token=xyz',
        'access_token': 'xyz',
      };

      final att = ChatV2Attachment.fromMap(json);

      expect(att.id, '1064');
      expect(att.name, 'photo.png');
      expect(att.isImage, true);
      expect(att.fileSize, 2048);
      expect(att.accessToken, 'xyz');
      expect(att.resolveFullUrl('https://vuahethong.net'), 'https://vuahethong.net/web/image/1064');
    });

    test('ChatV2Message parses chatter message JSON correctly with image attachments', () {
      final json = {
        'id': 9876,
        'channel_id': 4255,
        'body': '<p>Đây là ảnh chụp màn hình</p>',
        'author_id': 22,
        'author_name': 'Bùi Tuấn Kiệt',
        'author_avatar': 'https://vuahethong.net/avatar.png',
        'date': '2026-08-14T03:15:00Z',
        'status': 'read',
        'attachment_ids': [1064, 1065],
        'attachments': [
          {
            'id': 1064,
            'name': 'screenshot.png',
            'mimetype': 'image/png',
            'download_url': '/api/v1/mobile/attachments/1064/download?access_token=xyz',
          }
        ],
      };

      final msg = ChatV2Message.fromMap(
        json,
        currentPartnerId: '99', // Not mine
      );

      expect(msg.id, '9876');
      expect(msg.channelId, '4255');
      expect(msg.content, 'Đây là ảnh chụp màn hình');
      expect(msg.authorName, 'Bùi Tuấn Kiệt');
      expect(msg.isMine, false);
      expect(msg.status, 'read');
      expect(msg.attachmentIds, contains('1064'));
      expect(msg.attachmentIds, contains('1065'));
      expect(msg.attachments.length, 1);
      expect(msg.attachments.first.isImage, true);
      expect(msg.hasImageAttachment, true);
    });

    test('ChatV2Message identifies isMine correctly', () {
      final json = {
        'id': 9877,
        'channel_id': 4255,
        'body': 'Tin nhắn của tôi',
        'author_id': 99,
        'author_name': 'Tân Ma',
      };

      final msg = ChatV2Message.fromMap(
        json,
        currentPartnerId: '99',
      );

      expect(msg.isMine, true);
    });

    test('ChatV2Channel handles null, empty, and malformed inputs gracefully', () {
      final json = <String, dynamic>{};
      final channel = ChatV2Channel.fromMap(json);

      expect(channel.id, '');
      expect(channel.name, 'Cuộc trò chuyện');
      expect(channel.isGroup, false);
      expect(channel.lastMessage, isNull);
      expect(channel.unreadCount, 0);
      expect(channel.memberNames, isEmpty);
    });

    test('ChatV2Message handles null and empty fields gracefully without throwing', () {
      final json = <String, dynamic>{
        'id': null,
        'body': null,
        'author_id': false,
      };

      final msg = ChatV2Message.fromMap(json);

      expect(msg.id, '');
      expect(msg.content, '');
      expect(msg.authorName, 'Thành viên');
      expect(msg.isMine, false);
      expect(msg.status, 'sent');
      expect(msg.attachmentIds, isEmpty);
      expect(msg.attachments, isEmpty);
      expect(msg.hasImageAttachment, false);
    });
  });

  group('ChatV2 Widgets', () {
    testWidgets('ChatV2MessageItem renders message text and timestamp', (tester) async {
      final msg = ChatV2Message(
        id: '1',
        channelId: '4255',
        content: 'Chào buổi sáng!',
        authorName: 'Tân',
        createdAt: DateTime(2026, 8, 14, 10, 30),
        isMine: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );

      expect(find.text('Chào buổi sáng!'), findsOneWidget);
      expect(find.text('10:30'), findsOneWidget);
    });

    testWidgets('ChatV2InputBar handles typing, image button, and send callback', (tester) async {
      String? sentText;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2InputBar(
              onSend: (text) async {
                sentText = text;
              },
              onSendImage: ({required bytes, required filename, mimetype, caption}) async {},
            ),
          ),
        ),
      );

      final imageBtn = find.byIcon(LucideIcons.image);
      expect(imageBtn, findsOneWidget);

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'Xin chào');
      await tester.pump();

      final sendBtn = find.byIcon(LucideIcons.send);
      await tester.tap(sendBtn);
      await tester.pump();

      expect(sentText, 'Xin chào');
    });
  });
}

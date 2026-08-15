import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_input_bar.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

void main() {
  group('ChatV2 Models Parsing & Image Detection', () {
    test('1. PNG attachment is correctly recognized as image', () {
      final pngAtt = ChatV2Attachment.fromMap({
        'id': 1001,
        'name': 'screenshot.png',
        'mimetype': 'image/png',
      });
      expect(pngAtt.isImage, true);
      expect(pngAtt.resolveFullUrl('https://vuahethong.net'), 'https://vuahethong.net/web/image/1001');
    });

    test('2. JPG and JPEG attachments are correctly recognized as images', () {
      final jpgAtt = ChatV2Attachment.fromMap({
        'id': 1002,
        'name': 'photo.jpg',
        'mimetype': 'image/jpeg',
      });
      expect(jpgAtt.isImage, true);

      final jpegAtt = ChatV2Attachment.fromMap({
        'id': 1003,
        'name': 'camera_capture.jpeg',
      });
      expect(jpegAtt.isImage, true);
    });

    test('3. PDF attachment is NOT recognized as image and recognized as document', () {
      final pdfAtt = ChatV2Attachment.fromMap({
        'id': 1004,
        'name': 'bao_cao_tai_chinh.pdf',
        'mimetype': 'application/pdf',
      });
      expect(pdfAtt.isImage, false);

      const pdfMsg = ChatV2Message(
        id: '201',
        channelId: '4255',
        content: 'Bao_gia_2026.pdf',
        authorName: 'Tân',
        isMine: false,
      );
      expect(pdfMsg.isImageFilename, false);
      expect(pdfMsg.isDocumentFilename, true);
    });

    test('4. Attachment missing mimeType detects from extension without crashing', () {
      final noMimeAtt = ChatV2Attachment.fromMap({
        'id': 1005,
        'name': 'picture_without_mime.png',
        'mimetype': null,
      });
      expect(noMimeAtt.isImage, true);
      expect(noMimeAtt.name, 'picture_without_mime.png');
    });

    test('5. Malformed and null attachment payloads do not crash', () {
      final emptyAtt = ChatV2Attachment.fromMap({});
      expect(emptyAtt.id, '');
      expect(emptyAtt.name, 'attachment');
      expect(emptyAtt.isImage, false);

      final nullMsg = ChatV2Message.fromMap({
        'id': null,
        'body': null,
        'attachments': [null, 'invalid', 123],
        'attachment_ids': [null, false, 'abc'],
      });
      expect(nullMsg.id, '');
      expect(nullMsg.content, '');
      expect(nullMsg.attachments, isEmpty);
      expect(nullMsg.attachmentIds, isEmpty);
    });

    test('6. ChatV2Channel parses Odoo channel JSON correctly', () {
      final json = {
        'id': 4255,
        'name': 'Bùi Tuấn Kiệt',
        'channel_type': 'chat',
        'is_group': false,
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
      expect(channel.unreadCount, 3);
      expect(channel.memberNames, contains('Bùi Tuấn Kiệt'));
    });

    test('7. ChatV2Message parses chatter message JSON correctly with image attachments', () {
      final json = {
        'id': 9876,
        'channel_id': 4255,
        'body': '<p>Đây là ảnh chụp màn hình</p>',
        'author_id': 22,
        'author_name': 'Bùi Tuấn Kiệt',
        'author_avatar': 'https://vuahethong.net/avatar.png',
        'date': '2026-08-14T03:15:00Z',
        'status': 'read',
        'attachment_ids': [1064],
        'attachments': [
          {
            'id': 1064,
            'name': 'screenshot.png',
            'mimetype': 'image/png',
          }
        ],
      };

      final msg = ChatV2Message.fromMap(json, currentPartnerId: '99');
      expect(msg.id, '9876');
      expect(msg.content, 'Đây là ảnh chụp màn hình');
      expect(msg.hasImageAttachment, true);
      expect(msg.attachments.first.isImage, true);
    });
  });

  group('ChatV2 Widgets Rendering', () {
    testWidgets('8. ChatV2MessageItem renders normal text message', (tester) async {
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

    testWidgets('9. ChatV2MessageItem renders image attachment branch', (tester) async {
      final msg = ChatV2Message(
        id: '2',
        channelId: '4255',
        content: 'Sent attachment',
        authorName: 'Tân',
        createdAt: DateTime(2026, 8, 14, 10, 32),
        isMine: true,
        attachments: [
          const ChatV2Attachment(
            id: '91856',
            name: 'sample_photo.png',
            mimetype: 'image/png',
            url: '/web/image/91856',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );

      // Should render image container
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('10. ChatV2MessageItem renders filename card for image/doc filename', (tester) async {
      const imgNameMsg = ChatV2Message(
        id: '3',
        channelId: '4255',
        content: 'scaled_Screenshot-0405-094025.png',
        authorName: 'Tân',
        isMine: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: imgNameMsg),
          ),
        ),
      );

      expect(find.text('Hình ảnh'), findsOneWidget);
      expect(find.text('scaled_Screenshot-0405-094025.png'), findsOneWidget);
    });

    testWidgets('11. ChatV2InputBar handles typing, image button, and send callback', (tester) async {
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

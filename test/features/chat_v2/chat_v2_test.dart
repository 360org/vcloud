import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_list_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_input_bar.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_messages_controller.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_info_sheet.dart';

void main() {
  group('ChatV2 Model & Parsing Tests', () {
    test('1. PNG attachment is correctly recognized as image', () {
      const att = ChatV2Attachment(
        id: '101',
        name: 'screenshot.png',
        mimetype: 'image/png',
        url: '/web/image/101',
      );
      expect(att.isImage, isTrue);
      expect(att.extension, 'png');
    });

    test('2. JPG, JPEG, and SVG attachments are correctly recognized as images', () {
      const attJpg = ChatV2Attachment(
        id: '102',
        name: 'photo.jpg',
        mimetype: 'image/jpeg',
      );
      const attJpeg = ChatV2Attachment(
        id: '103',
        name: 'photo.jpeg',
        mimetype: 'image/jpeg',
      );
      const attSvg = ChatV2Attachment(
        id: '104',
        name: 'scaled_badge.svg',
        mimetype: 'image/svg+xml',
      );
      expect(attJpg.isImage, isTrue);
      expect(attJpeg.isImage, isTrue);
      expect(attSvg.isImage, isTrue);
      expect(attSvg.extension, 'svg');
    });

    test('3. PDF attachment is NOT recognized as image and recognized as document', () {
      const att = ChatV2Attachment(
        id: '105',
        name: 'report.pdf',
        mimetype: 'application/pdf',
      );
      expect(att.isImage, isFalse);
      expect(att.extension, 'pdf');
    });

    test('4. Attachment with missing mimeType detects from extension without crashing', () {
      const att = ChatV2Attachment(
        id: '106',
        name: 'image.PNG',
        mimetype: '',
      );
      expect(att.isImage, isTrue);
      expect(att.extension, 'png');
    });

    test('5. Malformed and null attachment payloads do not crash fromMap', () {
      final msgWithNull = ChatV2Message.fromMap({
        'id': 1,
        'body': 'Hello',
        'attachments': null,
      });
      expect(msgWithNull.attachments, isEmpty);

      final msgWithEmpty = ChatV2Message.fromMap({
        'id': 2,
        'body': 'Hello',
        'attachments': [],
      });
      expect(msgWithEmpty.attachments, isEmpty);

      final msgWithMalformed = ChatV2Message.fromMap({
        'id': 3,
        'body': 'Hello',
        'attachments': ['not a map', 123, null],
      });
      expect(msgWithMalformed.attachments, isEmpty);
    });

    test('6. ChatV2Channel parses Odoo channel JSON correctly', () {
      const jsonStr = '''
      {
        "id": 4255,
        "name": "Team Dev",
        "channel_type": "group",
        "message_unread_counter": 3,
        "last_message": {
          "body": "See screenshot",
          "date": "2026-08-14T03:00:00"
        }
      }
      ''';
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final channel = ChatV2Channel.fromMap(map);

      expect(channel.id, '4255');
      expect(channel.name, 'Team Dev');
      expect(channel.isGroup, isTrue);
      expect(channel.unreadCount, 3);
      expect(channel.lastMessage, 'See screenshot');
    });

    test('6b. ChatV2Channel getCleanName parses names with internal commas like Chau, Le Ba correctly', () {
      const ch1 = ChatV2Channel(
        id: '1',
        name: 'Ma Nguyễn Nhật Tân, Chau, Le Ba',
        channelType: 'chat',
        isGroup: false,
        unreadCount: 0,
      );
      expect(ch1.getCleanName('Ma Nguyễn Nhật Tân'), 'Chau, Le Ba');
      expect(ch1.getActualIsGroup('Ma Nguyễn Nhật Tân'), isFalse);

      const ch2 = ChatV2Channel(
        id: '2',
        name: 'Chau, Le Ba, Ma Nguyễn Nhật Tân',
        channelType: 'chat',
        isGroup: false,
        unreadCount: 0,
      );
      expect(ch2.getCleanName('Ma Nguyễn Nhật Tân'), 'Chau, Le Ba');

      const ch3 = ChatV2Channel(
        id: '3',
        name: 'Ma Nguyễn Nhật Tân, Bùi Tuấn Kiệt',
        channelType: 'chat',
        isGroup: false,
        unreadCount: 0,
      );
      expect(ch3.getCleanName('Ma Nguyễn Nhật Tân'), 'Bùi Tuấn Kiệt');
    });

    test('7. ChatV2Message parses Odoo chatter message JSON correctly with image attachments', () {
      const jsonStr = '''
      {
        "id": 586640,
        "body": "<p>Check this image</p>",
        "author_id": 6713,
        "author_name": "Tân",
        "date": "2026-08-14T03:30:00",
        "attachments": [
          {
            "id": 91856,
            "name": "diagram.png",
            "mimetype": "image/png",
            "url": "https://vuahethong.net/web/image/91856"
          },
          {
            "id": 91857,
            "name": "spec.pdf",
            "mimetype": "application/pdf",
            "url": "https://vuahethong.net/web/content/91857"
          }
        ]
      }
      ''';
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final msg = ChatV2Message.fromMap(map);

      expect(msg.id, '586640');
      expect(msg.content, 'Check this image');
      expect(msg.authorName, 'Tân');
      expect(msg.hasImageAttachment, isTrue);
      expect(msg.attachments.length, 2);
      expect(msg.attachments[0].isImage, isTrue);
      expect(msg.attachments[1].isImage, isFalse);
    });
  });

  group('ChatV2 Widget Rendering Tests', () {
    testWidgets('8. ChatV2MessageItem renders normal text message', (tester) async {
      const msg = ChatV2Message(
        id: '1',
        channelId: '4255',
        content: 'Hello World',
        authorName: 'Tân',
        isMine: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('9. ChatV2MessageItem renders image attachment branch', (tester) async {
      const msg = ChatV2Message(
        id: '2',
        channelId: '4255',
        content: '',
        authorName: 'Tân',
        isMine: false,
        attachments: [
          ChatV2Attachment(
            id: '91856',
            name: 'diagram.png',
            mimetype: 'image/png',
            url: '/web/image/91856',
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );

      // Should render image attachment widget
      expect(find.byType(ChatV2AttachmentImage), findsOneWidget);
    });

    testWidgets('10. ChatV2MessageItem renders filename card for historical image filename', (tester) async {
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

      expect(find.text('scaled_Screenshot-0405-094025.png'), findsOneWidget);
    });

    testWidgets('11. ChatV2InputBar handles typing, attachment button, and send callback', (tester) async {
      String? sentText;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2InputBar(
              onSend: (text) async {
                sentText = text;
              },
              onSendImage: ({required bytes, required filename, mimetype, caption}) async {},
              onSendFile: ({required bytes, required filename, mimetype, caption}) async {},
            ),
          ),
        ),
      );

      final attachmentBtn = find.byIcon(LucideIcons.paperclip);
      expect(attachmentBtn, findsOneWidget);

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'Xin chào');
      await tester.pump();

      final sendBtn = find.byIcon(LucideIcons.send);
      await tester.tap(sendBtn);
      await tester.pump();

      expect(sentText, 'Xin chào');
    });

    testWidgets('12. ChatV2MessageItem renders document attachment card with download icon', (tester) async {
      const docMsg = ChatV2Message(
        id: '4',
        channelId: '4255',
        content: 'Báo cáo tháng 8',
        authorName: 'Tân',
        isMine: false,
        attachments: [
          ChatV2Attachment(
            id: '91865',
            name: 'BaoCaoT8.pdf',
            mimetype: 'application/pdf',
            url: '/web/image/91865',
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: docMsg),
          ),
        ),
      );

      expect(find.textContaining('Tài liệu'), findsOneWidget);
      expect(find.text('BaoCaoT8.pdf'), findsOneWidget);
      expect(find.byIcon(LucideIcons.download), findsOneWidget);
      expect(find.text('Báo cáo tháng 8'), findsOneWidget);
    });

    test('13. My own sent messages are recognized as isMine and do not trigger unread state', () {
      final channel = ChatV2Channel(
        id: '123',
        name: 'Bùi Tuấn Kiệt',
        channelType: 'chat',
        lastMessage: 'scaled_logo_Vcloud.png',
        lastMessageAuthorId: '3',
        lastMessageAuthorName: 'Tân',
        lastMessageDate: DateTime.now(),
        unreadCount: 0,
      );

      final isMine = channel.isLastMessageFromMe(
        currentUserName: 'Tân',
        currentPartnerId: '3',
      );

      expect(isMine, isTrue);
    });

    test('14. Messages received from others are recognized as not isMine', () {
      final channel = ChatV2Channel(
        id: '123',
        name: 'Bùi Tuấn Kiệt',
        channelType: 'chat',
        lastMessage: 'Dạ vâng anh',
        lastMessageAuthorId: '99',
        lastMessageAuthorName: 'Bùi Tuấn Kiệt',
        lastMessageDate: DateTime.now(),
        unreadCount: 1,
      );

      final isMine = channel.isLastMessageFromMe(
        currentUserName: 'Tân',
        currentPartnerId: '3',
      );

      expect(isMine, isFalse);
    });

    test('15. Image message creates valid optimistic structure with pending status', () {
      final dummyBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      const tempId = 'temp_att_123456';
      final msg = ChatV2Message(
        id: tempId,
        channelId: '1',
        content: 'test_image.png',
        authorName: 'Tân',
        createdAt: DateTime.now(),
        isMine: true,
        status: 'pending',
        attachments: [
          ChatV2Attachment(
            id: tempId,
            name: 'test_image.png',
            mimetype: 'image/png',
            bytes: dummyBytes,
          ),
        ],
      );

      expect(msg.status, equals('pending'));
      expect(msg.attachments.first.isImage, isTrue);
      expect(msg.attachments.first.bytes, isNotNull);
    });

    test('16. Error status on message preserves existing chat history safely', () {
      final dummyBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final msg = ChatV2Message(
        id: 'temp_att_fail',
        channelId: '1',
        content: 'test_fail.png',
        authorName: 'Tân',
        createdAt: DateTime.now(),
        isMine: true,
        status: 'pending',
        attachments: [
          ChatV2Attachment(
            id: 'temp_att_fail',
            name: 'test_fail.png',
            mimetype: 'image/png',
            bytes: dummyBytes,
          ),
        ],
      );

      final updated = msg.copyWith(status: 'error');
      expect(updated.status, equals('error'));
      expect(updated.attachments.length, equals(1));
    });

    testWidgets('17. ChatV2MessageItem renders clickable URL link correctly', (tester) async {
      final msg = ChatV2Message(
        id: 'msg_link',
        channelId: '1',
        content: 'Meeting link https://teams.microsoft.com/meet/123 vui lòng tham gia nhé',
        authorName: 'Bùi Tuấn Kiệt',
        createdAt: DateTime.now(),
        isMine: false,
        status: 'sent',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );

      expect(find.byType(Text), findsWidgets);
      expect(find.textContaining('teams.microsoft.com'), findsOneWidget);
    });

    testWidgets('18. ChatV2MessageItem renders domain-only URL without crashing', (tester) async {
      final msg = ChatV2Message(
        id: 'msg_domain',
        channelId: '1',
        content: 'Truy cập website vuahethong.net để xem chi tiết',
        authorName: 'Châu Lê Bá',
        createdAt: DateTime.now(),
        isMine: true,
        status: 'sent',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );

      expect(find.byType(Text), findsWidgets);
      expect(find.textContaining('vuahethong.net'), findsOneWidget);
    });

    testWidgets('19. ChatV2MessageItem renders web image attachment safely', (tester) async {
      final msg = ChatV2Message(
        id: 'msg_web_img',
        channelId: '1',
        content: '',
        authorName: 'Châu Lê Bá',
        createdAt: DateTime.now(),
        isMine: false,
        status: 'sent',
        attachments: const [
          ChatV2Attachment(
            id: '91854',
            name: 'image.png',
            mimetype: 'image/png',
            url: '/web/image/91854',
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

      expect(find.byType(ChatV2AttachmentImage), findsOneWidget);
    });

    test('20. ChatV2ListScreen accepts initialFilter configuration', () {
      const widgetUnread = ChatV2ListScreen(initialFilter: 'unread');
      expect(widgetUnread.initialFilter, equals('unread'));

      const widgetGroup = ChatV2ListScreen(initialFilter: 'group');
      expect(widgetGroup.initialFilter, equals('group'));

      const widgetDirect = ChatV2ListScreen(initialFilter: 'direct');
      expect(widgetDirect.initialFilter, equals('direct'));
    });

    test('21. ChatV2MessageLocalCache prepends new message at index 0 for reverse ListView', () {
      final msg1 = ChatV2Message(
        id: 'msg_1',
        channelId: 'test_chan_1',
        content: 'Tin nhắn cũ',
        authorName: 'Tôi',
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      final msg2 = ChatV2Message(
        id: 'msg_temp_2',
        channelId: 'test_chan_1',
        content: 'Tin nhắn mới tức thì 0.00s',
        authorName: 'Tôi',
        createdAt: DateTime.now(),
        status: 'pending',
      );

      ChatV2MessageLocalCache.set('test_chan_1', [msg1]);
      expect(ChatV2MessageLocalCache.get('test_chan_1')?.first.id, equals('msg_1'));

      ChatV2MessageLocalCache.prepend('test_chan_1', msg2);
      final cached = ChatV2MessageLocalCache.get('test_chan_1');
      expect(cached, isNotNull);
      expect(cached!.length, equals(2));
      expect(cached.first.id, equals('msg_temp_2'));
      expect(cached.first.status, equals('pending'));
    });

    test('22. ChatV2Message copyWith transitions pending to sent smoothly', () {
      final pendingMsg = ChatV2Message(
        id: 'temp_123',
        channelId: '1',
        content: 'Xin chào',
        authorName: 'Tôi',
        createdAt: DateTime.now(),
        isMine: true,
        status: 'pending',
      );
      final sentMsg = pendingMsg.copyWith(id: '9999', status: 'sent');
      expect(sentMsg.id, equals('9999'));
      expect(sentMsg.status, equals('sent'));
      expect(sentMsg.isMine, isTrue);
    });

    test('24. ChatV2Channel parses Odoo author name with commas correctly', () {
      final channel = ChatV2Channel(
        id: 'group_4128',
        name: 'Huy Erp',
        channelType: 'channel',
        isGroup: true,
        lastMessage: 'mình tiến hành dịch cho từng ngôn ngữ nhé anh Huy.',
        lastMessageAuthorName: 'Chau, Le Ba',
        lastMessageAuthorId: '102',
        lastMessageDate: DateTime.now(),
        unreadCount: 0,
        memberCount: 19,
      );

      expect(channel.lastMessageAuthorName, equals('Chau, Le Ba'));
      expect(channel.isGroup, isTrue);
    });

    test('25. ChatV2MessageLocalCache first returns newest message and author', () {
      final olderMsg = ChatV2Message(
        id: 'msg_old',
        channelId: 'group_4128',
        content: 'Ok, Thanks e. gio anh bat dau vao post day',
        authorName: 'Nguyễn Tường Huy',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final newestMsg = ChatV2Message(
        id: 'msg_new',
        channelId: 'group_4128',
        content: 'mình tiến hành dịch cho từng ngôn ngữ theo hướng dẫn nhé anh Huy.',
        authorName: 'Chau, Le Ba',
        createdAt: DateTime.now(),
      );

      ChatV2MessageLocalCache.set('group_4128', [newestMsg, olderMsg]);
      final cached = ChatV2MessageLocalCache.get('group_4128');
      expect(cached, isNotNull);
      expect(cached!.first.authorName, equals('Chau, Le Ba'));
      expect(cached.last.authorName, equals('Nguyễn Tường Huy'));
    });

    testWidgets('26. ChatV2InfoSheet renders 1-1 direct chat with clean name and quick actions', (tester) async {
      const channel = ChatV2Channel(
        id: 'direct_123',
        name: 'Ma Nguyễn Nhật Tân, Bùi Tuấn Kiệt',
        channelType: 'chat',
        isGroup: false,
        lastMessage: 'Hello anh',
        imStatus: 'online',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2InfoSheet(
              channel: channel,
              currentUserName: 'Ma Nguyễn Nhật Tân',
            ),
          ),
        ),
      );

      // Verify it displays partner's clean name and not current user's name
      expect(find.text('Bùi Tuấn Kiệt'), findsOneWidget);
      expect(find.text('Đang trực tuyến'), findsOneWidget);
      expect(find.text('Tìm kiếm'), findsOneWidget);
      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.text('Sao chép link'), findsOneWidget);
    });

    testWidgets('27. ChatV2InfoSheet renders group chat with member list and media hub', (tester) async {
      const channel = ChatV2Channel(
        id: 'group_999',
        name: 'Internal',
        channelType: 'channel',
        isGroup: true,
        memberCount: 7,
        memberNames: ['Ma Nguyễn Nhật Tân', 'Bùi Tuấn Kiệt', 'Châu Lê Bá'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2InfoSheet(
              channel: channel,
              currentUserName: 'Ma Nguyễn Nhật Tân',
            ),
          ),
        ),
      );

      expect(find.text('Internal'), findsOneWidget);
      expect(find.text('Nhóm trò chuyện • 7 thành viên'), findsOneWidget);
      expect(find.text('Thành viên (3)'), findsOneWidget);
      expect(find.text('Ảnh & Tài liệu'), findsOneWidget);
      expect(find.text('Ma Nguyễn Nhật Tân (Bạn)'), findsOneWidget);
      expect(find.text('Bùi Tuấn Kiệt'), findsOneWidget);
      expect(find.text('Châu Lê Bá'), findsOneWidget);
    });

    testWidgets('28. ChatV2InfoSheet comprehensively extracts images, documents and links', (tester) async {
      const channel = ChatV2Channel(
        id: 'direct_123',
        name: 'Ma Nguyễn Nhật Tân, Bùi Tuấn Kiệt',
        channelType: 'chat',
        isGroup: false,
      );

      final messages = [
        ChatV2Message(
          id: '1',
          channelId: 'direct_123',
          content: 'https://google.com và http://localhost:8088/#/chat',
          authorName: 'Bùi Tuấn Kiệt',
          createdAt: DateTime.now(),
        ),
        ChatV2Message(
          id: '2',
          channelId: 'direct_123',
          content: 'scaled_image_picker_anniversary.png',
          authorName: 'Bùi Tuấn Kiệt',
          createdAt: DateTime.now(),
        ),
        ChatV2Message(
          id: '3',
          channelId: 'direct_123',
          content: 'mobileprovision_base64_client.txt',
          authorName: 'Bùi Tuấn Kiệt',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2InfoSheet(
              channel: channel,
              currentUserName: 'Ma Nguyễn Nhật Tân',
              messages: messages,
            ),
          ),
        ),
      );

      expect(find.text('Ảnh (1)'), findsOneWidget);
      expect(find.text('Tài liệu (1)'), findsOneWidget);
      expect(find.text('Liên kết (2)'), findsOneWidget);
    });

    test('29. ChatV2Attachment supports copyWith and preserves bytes accurately', () {
      const att = ChatV2Attachment(
        id: '101',
        name: 'test_logo.png',
        mimetype: 'image/png',
      );
      final rawBytes = Uint8List.fromList([1, 2, 3, 4]);
      final updated = att.copyWith(bytes: rawBytes);

      expect(updated.id, '101');
      expect(updated.name, 'test_logo.png');
      expect(updated.bytes, isNotNull);
      expect(updated.bytes!.length, 4);
      expect(updated.isImage, isTrue);
    });
  });
}

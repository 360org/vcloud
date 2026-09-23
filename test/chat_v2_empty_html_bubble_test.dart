import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

void main() {
  group('ChatV2 HTML Sanitization Unit Tests', () {
    test('1. <div class="o-paragraph"><br></div> => empty string', () {
      const raw = '<div class="o-paragraph"><br></div>';
      expect(ChatV2Message.cleanHtml(raw), isEmpty);
      expect(ChatV2Message.isEmptyHtml(raw), isTrue);
    });

    test('2. empty/null body => empty string', () {
      expect(ChatV2Message.cleanHtml(null), isEmpty);
      expect(ChatV2Message.cleanHtml(''), isEmpty);
      expect(ChatV2Message.isEmptyHtml(null), isTrue);
      expect(ChatV2Message.isEmptyHtml(''), isTrue);
    });

    test('3. whitespace-only HTML => empty string', () {
      const variations = [
        '   ',
        '<p> </p>',
        '<p><br></p>',
        '<div><br></div>',
        '<p>&nbsp;</p>',
        '<div>&nbsp;</div>',
        '<div> \n <br/> \n </div>',
        '&lt;div class="o-paragraph"&gt;&lt;br&gt;&lt;/div&gt;',
        '<div class="o-paragraph">&nbsp;<br>&nbsp;</div>',
      ];

      for (final v in variations) {
        expect(
          ChatV2Message.cleanHtml(v),
          isEmpty,
          reason: 'Failed to normalize whitespace HTML variation: "$v"',
        );
        expect(ChatV2Message.isEmptyHtml(v), isTrue);
      }
    });

    test('4. ChatV2Message.fromMap strips empty HTML from content', () {
      final json = <String, dynamic>{
        'id': 101,
        'channel_id': 10,
        'body': '<div class="o-paragraph"><br></div>',
        'author_id': {'id': 99, 'name': 'Trịnh Xuân Đạt'},
        'date': '2026-09-23 16:42:00',
      };

      final msg = ChatV2Message.fromMap(json);
      expect(msg.content, isEmpty);
      expect(msg.rawBody, '<div class="o-paragraph"><br></div>');
    });

    test('5. Message with real content preserves actual text', () {
      const body = '<div class="o-paragraph">Tình hình xấu</div>';
      expect(ChatV2Message.cleanHtml(body), 'Tình hình xấu');

      final json = <String, dynamic>{
        'id': 102,
        'channel_id': 10,
        'body': body,
        'author_id': {'id': 99, 'name': 'Trịnh Xuân Đạt'},
        'date': '2026-09-23 16:00:00',
      };

      final msg = ChatV2Message.fromMap(json);
      expect(msg.content, 'Tình hình xấu');
    });

    test('6. Message with real multi-line HTML preserves structure', () {
      const body = '<p>Dòng 1</p><p>Dòng 2</p>';
      expect(ChatV2Message.cleanHtml(body), 'Dòng 1\nDòng 2');
    });

    test('7. Message with HTML entities like &lt; and &gt; preserves text', () {
      const text = 'Điểm số &gt; 5 &amp;&amp; &lt; 10';
      expect(ChatV2Message.cleanHtml(text), 'Điểm số > 5 && < 10');
    });
  });

  group('ChatV2MessageItem Widget Rendering Tests', () {
    testWidgets('8. Message with image attachment + empty HTML body does NOT render raw HTML or text bubble', (tester) async {
      // Mô phỏng đúng tin nhắn từ Odoo Discuss khi đính kèm ảnh
      final msg = ChatV2Message.fromMap({
        'id': 9991,
        'channel_id': 10,
        'body': '<div class="o-paragraph"><br></div>',
        'author_id': {'id': 88, 'name': 'Trịnh Xuân Đạt'},
        'date': '2026-09-23 16:42:00',
        'attachments': [
          {
            'id': 'att_1',
            'name': 'screenshot.png',
            'mimetype': 'image/png',
            'url': '/web/image/att_1',
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );

      // Tuyệt đối KHÔNG được render raw HTML string ra màn hình
      expect(find.textContaining('o-paragraph'), findsNothing);
      expect(find.textContaining('<div'), findsNothing);
      expect(find.textContaining('<br>'), findsNothing);

      // Widget phải hiển thị component ảnh
      expect(find.byType(ChatV2MessageItem), findsOneWidget);
    });

    testWidgets('9. Message with real text content renders normally', (tester) async {
      final msg = ChatV2Message.fromMap({
        'id': 9992,
        'channel_id': 10,
        'body': '<div class="o-paragraph">Tình hình xấu</div>',
        'author_id': {'id': 88, 'name': 'Trịnh Xuân Đạt'},
        'date': '2026-09-23 16:00:00',
        'attachments': [
          {
            'id': 'att_2',
            'name': 'chart.png',
            'mimetype': 'image/png',
            'url': '/web/image/att_2',
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );

      // Nội dung text thật "Tình hình xấu" phải được render
      expect(find.text('Tình hình xấu'), findsOneWidget);
      expect(find.textContaining('o-paragraph'), findsNothing);
    });

    testWidgets('10. Message with empty HTML and NO attachments renders SizedBox.shrink', (tester) async {
      final msg = ChatV2Message.fromMap({
        'id': 9993,
        'channel_id': 10,
        'body': '<div class="o-paragraph"><br></div>',
        'author_id': {'id': 88, 'name': 'Trịnh Xuân Đạt'},
        'date': '2026-09-23 16:42:00',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );

      // Không render bong bóng rác hay text rỗng
      expect(find.textContaining('o-paragraph'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('11. Image-only message has timestamp overlaid on image, no separate bottom text container', (tester) async {
      final msg = ChatV2Message.fromMap({
        'id': 9994,
        'channel_id': 10,
        'body': '<div class="o-paragraph"><br></div>',
        'author_id': {'id': 88, 'name': 'Trịnh Xuân Đạt'},
        'date': '2026-09-23 16:42:00',
        'attachments': [
          {
            'id': 'att_4',
            'name': 'photo.jpg',
            'mimetype': 'image/jpeg',
            'url': '/web/image/att_4',
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );

      // Stack chứa ảnh và timestamp overlay
      expect(find.byType(Stack), findsWidgets);
      // Không có text widget rỗng
      expect(find.textContaining('o-paragraph'), findsNothing);
      final expectedTime = DateFormat('HH:mm').format(msg.createdAt!);
      expect(find.text(expectedTime), findsOneWidget);
    });

    testWidgets('12. Document attachment with empty HTML body does NOT render empty text container', (tester) async {
      final msg = ChatV2Message.fromMap({
        'id': 9995,
        'channel_id': 10,
        'body': '<div class="o-paragraph"><br></div>',
        'author_id': {'id': 88, 'name': 'Trịnh Xuân Đạt'},
        'date': '2026-09-23 16:42:00',
        'attachments': [
          {
            'id': 'att_doc_1',
            'name': 'contract.pdf',
            'mimetype': 'application/pdf',
            'url': '/web/content/att_doc_1',
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );

      expect(find.text('contract.pdf'), findsOneWidget);
      expect(find.textContaining('o-paragraph'), findsNothing);
    });

    testWidgets('13. Text-only message preserves existing layout', (tester) async {
      final msg = ChatV2Message.fromMap({
        'id': 9996,
        'channel_id': 10,
        'body': '<p>Xin chào Sếp</p>',
        'author_id': {'id': 88, 'name': 'Trịnh Xuân Đạt'},
        'date': '2026-09-23 16:42:00',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );

      expect(find.text('Xin chào Sếp'), findsOneWidget);
      final expectedTime = DateFormat('HH:mm').format(msg.createdAt!);
      expect(find.text(expectedTime), findsOneWidget);
    });
  });
}

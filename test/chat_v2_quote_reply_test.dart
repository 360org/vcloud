import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';

void main() {
  group('ChatV2 Quoted Reply & HTML Parsing Tests', () {
    test('ChatV2Message parses normal text without quotes', () {
      final json = <String, dynamic>{
        'id': 501,
        'channel_id': 10,
        'body': '<p>Xin chào mọi người</p>',
        'author_id': {'id': 10, 'name': 'Anh Tân'},
        'date': '2026-08-19 14:30:00',
        'message_type': 'comment',
      };

      final msg = ChatV2Message.fromMap(json);
      expect(msg.id, '501');
      expect(msg.authorName, 'Anh Tân');
      expect(msg.content.contains('Xin chào mọi người'), isTrue);
    });

    test('ChatV2Message parses embedded blockquote reply with parent reference', () {
      final json = <String, dynamic>{
        'id': 502,
        'channel_id': 10,
        'body': '<blockquote data-oe-model="mail.message" data-oe-id="501">'
            '<p><strong>Anh Tân</strong>: Xin chào mọi người</p>'
            '</blockquote>'
            '<p>Chào anh Tân nhé!</p>',
        'author_id': {'id': 11, 'name': 'Sếp Châu'},
        'parent_id': 501,
        'parent_body': 'Xin chào mọi người',
        'parent_author_name': 'Anh Tân',
        'date': '2026-08-19 14:32:00',
        'message_type': 'comment',
      };

      final msg = ChatV2Message.fromMap(json);
      expect(msg.id, '502');
      expect(msg.authorName, 'Sếp Châu');
      expect(msg.parentId, '501');
      expect(msg.parentAuthorName, 'Anh Tân');
      expect(msg.parentBody, 'Xin chào mọi người');
      expect(msg.content.contains('Chào anh Tân nhé!'), isTrue);
    });

    test('ChatV2Message handles null parent and empty body safely', () {
      final json = <String, dynamic>{
        'id': 503,
        'channel_id': 10,
        'body': false,
        'author_id': false,
        'author_name': false,
        'date': false,
      };

      final msg = ChatV2Message.fromMap(json);
      expect(msg.id, '503');
      expect(msg.authorName, 'Người dùng');
      expect(msg.content, '');
      expect(msg.parentId, isNull);
      expect(msg.parentBody, isNull);
    });
  });
}

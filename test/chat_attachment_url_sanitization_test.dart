import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/shared/models/message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Message Attachment URL Sanitization Tests', () {
    test('prioritizes download_url over absolute url and legacy fields', () {
      final map = {
        'id': 100,
        'body': 'test message',
        'attachments': [
          {
            'id': 1142,
            'name': '05_chat_screen.png',
            'mimetype': 'image/png',
            'url': 'http://localhost:8069/web/content/1142/05_chat_screen.png',
            'download_url': '/api/v1/mobile/attachments/1142/download',
          }
        ]
      };

      final msg = Message.fromOdooMessageInfo(conversationId: '25', map: map);
      expect(msg.attachmentUrl, equals('/api/v1/mobile/attachments/1142/download'));
    });

    test('sanitizes legacy http://localhost:8069 url to relative path if download_url is missing', () {
      final map = {
        'id': 101,
        'body': 'test message',
        'attachments': [
          {
            'id': 1143,
            'name': 'photo.jpg',
            'mimetype': 'image/jpeg',
            'url': 'http://localhost:8069/web/content/1143/photo.jpg',
          }
        ]
      };

      final msg = Message.fromOdooMessageInfo(conversationId: '25', map: map);
      expect(msg.attachmentUrl, equals('/web/content/1143/photo.jpg'));
      expect(msg.attachmentUrl!.startsWith('http://localhost'), isFalse);
    });

    test('sanitizes 127.0.0.1 hostname to relative path', () {
      final map = {
        'id': 102,
        'body': 'test message',
        'attachments': [
          {
            'id': 1144,
            'name': 'document.pdf',
            'mimetype': 'application/pdf',
            'url': 'http://127.0.0.1:8069/web/content/1144?download=1',
          }
        ]
      };

      final msg = Message.fromOdooMessageInfo(conversationId: '25', map: map);
      expect(msg.attachmentUrl, equals('/web/content/1144?download=1'));
    });

    test('preserves valid relative paths and attaches access_token if present', () {
      final map = {
        'id': 103,
        'body': 'test message',
        'attachments': [
          {
            'id': 1145,
            'name': 'image.png',
            'mimetype': 'image/png',
            'url': '/web/image/1145/300x300',
            'access_token': 'secret_token_123',
          }
        ]
      };

      final msg = Message.fromOdooMessageInfo(conversationId: '25', map: map);
      expect(msg.attachmentUrl, equals('/web/image/1145/300x300?access_token=secret_token_123'));
    });
  });
}

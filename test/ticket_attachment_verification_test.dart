import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/mobile_attachment_repository.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';

void main() {
  group('Ticket Attachment Unit & Contract Tests', () {
    test('MobileAttachment.fromMap parses valid file name correctly', () {
      final json = {
        'id': 91617,
        'name': 'Báo_cáo_tài_chính_Q2.pdf',
        'mimetype': 'application/pdf',
        'file_size': 1048576,
      };

      final attachment = MobileAttachment.fromMap(json);

      expect(attachment.id, 91617);
      expect(attachment.name, 'Báo_cáo_tài_chính_Q2.pdf');
      expect(attachment.mimetype, 'application/pdf');
      expect(attachment.fileSize, 1048576);
    });

    test('MobileAttachment.fromMap sanitizes "undefined", "null", or empty names', () {
      final jsonUndefined = {'id': 91618, 'name': 'undefined'};
      final jsonNull = {'id': 91619, 'name': 'null'};
      final jsonEmpty = {'id': 91620, 'name': '   '};

      final attUndefined = MobileAttachment.fromMap(jsonUndefined);
      final attNull = MobileAttachment.fromMap(jsonNull);
      final attEmpty = MobileAttachment.fromMap(jsonEmpty);

      expect(attUndefined.name, 'Tệp đính kèm #91618');
      expect(attNull.name, 'Tệp đính kèm #91619');
      expect(attEmpty.name, 'Tệp đính kèm #91620');
    });

    test('odooApiClient.authenticatedUrl builds valid GET download URL with access_token', () {
      final client = OdooApiClient(baseUrl: 'https://vuahethong.net');

      final downloadUrl = client.authenticatedUrl(
        '/api/v1/mobile/attachments/91617/download',
        accessToken: 'mock_jwt_token_12345',
      );

      expect(
        downloadUrl,
        'https://vuahethong.net/api/v1/mobile/attachments/91617/download?access_token=mock_jwt_token_12345',
      );
    });

    test('MobileAttachment.fromMap parses download_url and access_token', () {
      final json = {
        'id': 91621,
        'name': 'screenshot.jpg',
        'mimetype': 'image/jpeg',
        'file_size': 2048,
        'access_token': 'secret_random_token_abc',
        'download_url': '/api/v1/mobile/attachments/91621/download?access_token=secret_random_token_abc',
      };

      final attachment = MobileAttachment.fromMap(json);

      expect(attachment.id, 91621);
      expect(attachment.accessToken, 'secret_random_token_abc');
      expect(attachment.downloadUrl, '/api/v1/mobile/attachments/91621/download?access_token=secret_random_token_abc');

      final client = OdooApiClient(baseUrl: 'https://vuahethong.net');
      final finalUrl = client.authenticatedUrl(
        attachment.downloadUrl ?? '/api/v1/mobile/attachments/${attachment.id}/download',
        accessToken: attachment.accessToken,
      );

      expect(
        finalUrl,
        'https://vuahethong.net/api/v1/mobile/attachments/91621/download?access_token=secret_random_token_abc',
      );
    });

    test('Extension and Mimetype detection for PDF, Image, Spreadsheet, Document', () {
      final files = [
        {'name': 'document.pdf', 'mime': 'application/pdf'},
        {'name': 'photo.png', 'mime': 'image/png'},
        {'name': 'excel.xlsx', 'mime': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'},
        {'name': 'word.docx', 'mime': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'},
      ];

      for (final f in files) {
        final att = MobileAttachment.fromMap({'id': 1, 'name': f['name'], 'mimetype': f['mime']});
        expect(att.name, f['name']);
        expect(att.mimetype, f['mime']);
      }
    });
  });
}

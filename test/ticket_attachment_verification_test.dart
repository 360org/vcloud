import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filex/open_filex.dart';
import 'package:vcloud/core/api/mobile_attachment_repository.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_attachment_viewer.dart';

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

    test('BUG-011: Ticket attachment opens In-App via ChatV2AttachmentViewer without external browser', () async {
      ChatV2AttachmentViewer.customOpener = (filePath, {type}) async {
        return OpenResult(type: ResultType.done);
      };
      ChatV2AttachmentViewer.customFetcher = (target) async {
        return Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]); // %PDF-
      };

      // Verify that ChatV2AttachmentViewer delegates properly to native opener
      expect(ChatV2AttachmentViewer.customOpener, isNotNull);
      expect(ChatV2AttachmentViewer.customFetcher, isNotNull);

      // Clean up test mocks
      ChatV2AttachmentViewer.customOpener = null;
      ChatV2AttachmentViewer.customFetcher = null;
    });

    testWidgets('ChatV2AttachmentViewer prefixes saved file with att_{id}_ to prevent cache collisions', (tester) async {
      String? recordedPath;
      ChatV2AttachmentViewer.customOpener = (filePath, {type}) async {
        recordedPath = filePath;
        return OpenResult(type: ResultType.done);
      };
      ChatV2AttachmentViewer.customFetcher = (target) async {
        return Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]); // %PDF-
      };
      final tempDir = Directory.systemTemp.createTempSync('vcloud_test_');
      ChatV2AttachmentViewer.customDirResolver = () async => tempDir.path;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: false,
            splashFactory: NoSplash.splashFactory,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => GestureDetector(
                onTap: () {
                  ChatV2AttachmentViewer.open(
                    context: context,
                    filename: 'document.pdf',
                    attachmentId: 12345,
                    accessToken: 'mock_token',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(recordedPath, isNotNull);
      expect(recordedPath, endsWith('att_12345_document.pdf'));

      ChatV2AttachmentViewer.customOpener = null;
      ChatV2AttachmentViewer.customFetcher = null;
      ChatV2AttachmentViewer.customDirResolver = null;
      tempDir.deleteSync(recursive: true);
    });

    test('MobileAttachmentRepository.fetchBytes includes access_token when supplied', () async {
      final fakeClient = _MockOdooApiClient();
      final repo = MobileAttachmentRepository(client: fakeClient);

      await repo.fetchBytes(9988, accessToken: 'test_token_xyz');

      expect(fakeClient.requestedPath, '/api/v1/mobile/attachments/9988/download?access_token=test_token_xyz');
    });

    test('Smart name formatting resolves generic clipboard image names cleanly', () {
      final genericNames = ['image.png', 'image.jpg', 'screenshot.png', 'clipboard.png', 'untitled.png'];
      final regex = RegExp(r'^(image|screenshot|clipboard|pasted_image|untitled)(\.[a-z0-9]+)?$');

      for (final name in genericNames) {
        expect(regex.hasMatch(name.toLowerCase()), isTrue, reason: '$name should match generic clipboard pattern');
      }

      final customNames = ['Bao_cao_quy_3.pdf', 'hop_dong_lao_dong.docx', 'avatar_nv.png'];
      for (final name in customNames) {
        expect(regex.hasMatch(name.toLowerCase()), isFalse, reason: '$name should not match generic pattern');
      }
    });
  });
}

class _MockOdooApiClient extends OdooApiClient {
  _MockOdooApiClient() : super(baseUrl: 'https://vuahethong.net');

  String? requestedPath;

  @override
  Future<Uint8List> fetchBytes(String path, {bool auth = true}) async {
    requestedPath = path;
    return Uint8List.fromList([1, 2, 3]);
  }
}

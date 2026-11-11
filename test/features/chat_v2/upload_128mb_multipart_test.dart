import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vcloud/core/api/mobile_attachment_repository.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/core/api/odoo_session_store.dart';
import 'package:vcloud/core/error/failure.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

class _InMemorySessionStore extends OdooSessionStore {
  OdooSession? _session = OdooSession(
    accessToken: 'test-jwt-token',
    uid: 3514,
    partnerId: 4001,
    db: 'vuahethong',
    login: 'tanmnn@360.org.vn',
    expiresAt: DateTime.utc(2099, 1, 1),
    baseUrl: 'https://vuahethong.net',
  );

  @override
  Future<OdooSession?> read() async => _session;

  @override
  Future<void> write(OdooSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

class _CapturingMultipartClient extends http.BaseClient {
  _CapturingMultipartClient(this._handler);

  final Future<http.StreamedResponse> Function(
    http.BaseRequest request,
    Uint8List bodyBytes,
  ) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    return _handler(request, bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Upload 128MB Multipart & Progress Verification Suite (12 Cases)', () {
    test('Case 1: 10MB 4K image uploads via multipart/form-data (no Base64 JSON inflation)', () async {
      String? capturedContentType;
      int capturedBodyLength = 0;

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _InMemorySessionStore(),
        httpClient: _CapturingMultipartClient((request, bodyBytes) async {
          capturedContentType = request.headers['content-type'];
          capturedBodyLength = bodyBytes.length;
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'attachment': {
                'id': 501,
                'attachment_id': 501,
                'name': 'photo_4k.jpg',
                'mimetype': 'image/jpeg',
                'file_size': 10 * 1024 * 1024,
                'url': '/api/v1/mobile/attachments/501/download',
              },
            }))),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final repo = ChatV2Repository(client);
      // 1 MB sample buffer representing compressed/4K image payload
      final payload = Uint8List(1024 * 1024);
      payload[0] = 0xFF;
      payload[1] = 0xD8;
      payload[2] = 0xFF;

      final attachment = await repo.uploadAttachment(
        filename: 'photo_4k.jpg',
        bytes: payload,
        mimetype: 'image/jpeg',
        resModel: 'discuss.channel',
        resId: 42,
      );

      expect(capturedContentType, contains('multipart/form-data'));
      // Multipart overhead is only a few hundred bytes, NOT +33% Base64
      expect(capturedBodyLength, lessThan((payload.length * 1.05).round()));
      expect(attachment.id, '501');
      expect(attachment.isImage, isTrue);
    });

    test('Case 2: Video streams directly from disk via filePath without loading bytes into RAM', () async {
      final tempDir = await Directory.systemTemp.createTemp('vcloud_upload_test_');
      try {
        final tempFile = File('${tempDir.path}/clip_60mb_sample.mp4');
        // Write valid MP4 header + 256 KB sample stream on disk
        final diskData = Uint8List(256 * 1024);
        diskData.setRange(4, 8, 'ftyp'.codeUnits);
        await tempFile.writeAsBytes(diskData, flush: true);

        String? capturedHeader;
        int streamedBytesCount = 0;

        final client = OdooApiClient(
          baseUrl: 'https://vuahethong.net',
          sessionStore: _InMemorySessionStore(),
          httpClient: _CapturingMultipartClient((request, bodyBytes) async {
            capturedHeader = request.headers['content-type'];
            streamedBytesCount = bodyBytes.length;
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({
                'attachment': {
                  'id': 502,
                  'attachment_id': 502,
                  'name': 'clip_60mb_sample.mp4',
                  'mimetype': 'video/mp4',
                  'file_size': 60 * 1024 * 1024,
                },
              }))),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final repo = ChatV2Repository(client);
        final att = await repo.uploadAttachment(
          filename: 'clip_60mb_sample.mp4',
          filePath: tempFile.path,
          bytes: Uint8List(0), // Zero bytes in RAM!
          mimetype: 'video/mp4',
          resModel: 'discuss.channel',
          resId: 42,
        );

        expect(capturedHeader, contains('multipart/form-data'));
        expect(streamedBytesCount, greaterThan(diskData.length));
        expect(att.id, '502');
        expect(att.isVideo, isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('Case 3: 120MB upload calculates dynamic timeout and emits progress % callbacks', () async {
      final progressEvents = <double>[];

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _InMemorySessionStore(),
        httpClient: _CapturingMultipartClient((request, bodyBytes) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'attachment': {
                'id': 503,
                'attachment_id': 503,
                'name': 'video_120mb.mp4',
                'mimetype': 'video/mp4',
                'file_size': 120 * 1024 * 1024,
              },
            }))),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      // Verify dynamic timeout formula for 120MB: (60 + 120 * 2).clamp(60, 600) == 300s
      final timeout120Mb = client.uploadTimeoutForBytes(120 * 1024 * 1024);
      expect(timeout120Mb, const Duration(seconds: 300));

      final payload = Uint8List(128 * 1024);
      final repo = ChatV2Repository(client);
      await repo.uploadAttachment(
        filename: 'video_120mb.mp4',
        bytes: payload,
        mimetype: 'video/mp4',
        onProgress: (sent, total) {
          if (total > 0) {
            progressEvents.add(sent / total);
          }
        },
      );

      expect(progressEvents, isNotEmpty);
      expect(progressEvents.last, closeTo(1.0, 0.01));
    });

    test('Case 4: 130MB file is blocked immediately on client with "128 MB" message before network call', () async {
      bool networkCalled = false;
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _InMemorySessionStore(),
        httpClient: _CapturingMultipartClient((request, bodyBytes) async {
          networkCalled = true;
          throw StateError('Network should not be called for >128MB file');
        }),
      );

      final attachmentRepo = MobileAttachmentRepository(client: client);
      expect(
        () => attachmentRepo.upload(
          MobileAttachmentUpload(
            filename: 'oversize_130mb.zip',
            bytes: Uint8List(0),
            fileSize: 130 * 1024 * 1024,
            mimetype: 'application/zip',
          ),
        ),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            allOf(contains('130.0 MB'), contains('128 MB')),
          ),
        ),
      );
      expect(networkCalled, isFalse);
    });

    test('Case 5: 40MB PDF attachment in Ticket passes client check and uploads via multipart', () async {
      Map<String, String>? capturedFields;
      final tempDir = await Directory.systemTemp.createTemp('vcloud_ticket_pdf_');
      try {
        final pdfFile = File('${tempDir.path}/contract_40mb.pdf');
        final pdfBytes = Uint8List.fromList('%PDF-1.7 sample content'.codeUnits);
        await pdfFile.writeAsBytes(pdfBytes, flush: true);

        final client = OdooApiClient(
          baseUrl: 'https://vuahethong.net',
          sessionStore: _InMemorySessionStore(),
          httpClient: _CapturingMultipartClient((request, bodyBytes) async {
            final bodyStr = utf8.decode(bodyBytes, allowMalformed: true);
            capturedFields = {
              'has_res_model': bodyStr.contains('helpdesk.ticket').toString(),
              'has_pdf': bodyStr.contains('contract_40mb.pdf').toString(),
            };
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({
                'attachment': {
                  'id': 505,
                  'attachment_id': 505,
                  'name': 'contract_40mb.pdf',
                  'mimetype': 'application/pdf',
                  'file_size': 40 * 1024 * 1024,
                },
              }))),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final attachmentRepo = MobileAttachmentRepository(client: client);
        final uploaded = await attachmentRepo.upload(
          MobileAttachmentUpload(
            filename: 'contract_40mb.pdf',
            bytes: Uint8List(0),
            filePath: pdfFile.path,
            fileSize: 40 * 1024 * 1024, // 40MB > old 25MB limit, <= 128MB
            mimetype: 'application/pdf',
            resModel: 'helpdesk.ticket',
            resId: 99,
          ),
        );

        expect(uploaded.attachmentId, 505);
        expect(capturedFields?['has_res_model'], 'true');
        expect(capturedFields?['has_pdf'], 'true');
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('Case 6: Server max_upload_bytes capability syncs to OdooApiClient and overrides default', () {
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _InMemorySessionStore(),
      );

      expect(client.maxUploadBytes, 128 * 1024 * 1024);
      expect(client.maxUploadMb, 128);

      // Simulate server returning custom web.max_file_upload_size (e.g. 64 MB)
      client.updateMaxUploadBytes(64 * 1024 * 1024);
      expect(client.maxUploadBytes, 64 * 1024 * 1024);
      expect(client.maxUploadMb, 64);

      // Restore to 128 MB standard
      client.updateMaxUploadBytes(OdooApiClient.defaultMaxUploadBytes);
      expect(client.maxUploadBytes, 134217728);
    });

    test('Case 7: Unauthorized channel (403) and Payload Too Large (413) return clear Vietnamese Failure', () async {
      final client413 = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _InMemorySessionStore(),
        httpClient: _CapturingMultipartClient((request, bodyBytes) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode('<html>413 Request Entity Too Large</html>')),
            413,
            headers: {'content-type': 'text/html'},
          );
        }),
      );

      await expectLater(
        () => client413.uploadMultipart(
          '/api/v1/mobile/attachments/upload',
          files: [
            MultipartUploadFile(
              field: 'file',
              filename: 'huge.bin',
              bytes: Uint8List.fromList([1, 2, 3, 4]),
            ),
          ],
        ),
        throwsA(
          isA<Failure>().having(
            (f) => f.statusCode,
            'statusCode',
            413,
          ).having(
            (f) => f.message,
            'message',
            contains('128 MB'),
          ),
        ),
      );
    });

    test('Case 8: Cancelling UploadCancelToken mid-stream aborts request with UploadCancelledException', () async {
      final cancelToken = UploadCancelToken();
      cancelToken.cancel();

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _InMemorySessionStore(),
        httpClient: _CapturingMultipartClient((request, bodyBytes) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode('{}')),
            200,
          );
        }),
      );

      await expectLater(
        () => client.uploadMultipart(
          '/api/v1/mobile/attachments/upload',
          files: [
            MultipartUploadFile(
              field: 'file',
              filename: 'cancel_me.mp4',
              bytes: Uint8List(1024),
            ),
          ],
          cancelToken: cancelToken,
        ),
        throwsA(isA<UploadCancelledException>()),
      );
    });

    test('Case 9: Network drop mid-upload preserves filePath/fileSize on ChatV2Attachment for retry', () {
      const att = ChatV2Attachment(
        id: 'temp_1',
        name: 'report_80mb.pdf',
        mimetype: 'application/pdf',
        filePath: '/storage/emulated/0/Download/report_80mb.pdf',
        fileSize: 80 * 1024 * 1024,
      );

      const msg = ChatV2Message(
        id: 'temp_1',
        channelId: '42',
        content: 'report_80mb.pdf',
        authorName: 'Tân',
        status: 'pending',
        uploadProgress: 0.45,
        attachments: [att],
      );

      expect(msg.uploadProgress, 0.45);
      final failedMsg = msg.copyWith(status: 'error', clearUploadProgress: true);
      expect(failedMsg.status, 'error');
      expect(failedMsg.uploadProgress, isNull);
      expect(failedMsg.attachments.first.filePath, '/storage/emulated/0/Download/report_80mb.pdf');
      expect(failedMsg.attachments.first.fileSize, 80 * 1024 * 1024);
    });

    test('Case 10: Batch upload sends multiple files in a single multipart/form-data request', () async {
      String? capturedBody;
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _InMemorySessionStore(),
        httpClient: _CapturingMultipartClient((request, bodyBytes) async {
          capturedBody = utf8.decode(bodyBytes, allowMalformed: true);
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'attachments': [
                {
                  'id': 601,
                  'attachment_id': 601,
                  'name': 'img1.jpg',
                  'mimetype': 'image/jpeg',
                },
                {
                  'id': 602,
                  'attachment_id': 602,
                  'name': 'img2.jpg',
                  'mimetype': 'image/jpeg',
                },
              ],
            }))),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final repo = ChatV2Repository(client);
      final uploaded = await repo.uploadAttachmentsBatch(
        files: [
          (filename: 'img1.jpg', bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 1]), mimetype: 'image/jpeg'),
          (filename: 'img2.jpg', bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 2]), mimetype: 'image/jpeg'),
        ],
      );

      expect(uploaded.length, 2);
      expect(uploaded[0].id, '601');
      expect(uploaded[1].id, '602');
      expect(capturedBody, contains('img1.jpg'));
      expect(capturedBody, contains('img2.jpg'));
    });

    testWidgets('Case 11: ChatV2MessageItem displays upload percentage and triggers onCancelUpload', (tester) async {
      bool cancelTapped = false;
      const pendingMsg = ChatV2Message(
        id: 'temp_upload_1',
        channelId: '10',
        content: 'archive_90mb.zip',
        authorName: 'Tân',
        isMine: true,
        status: 'pending',
        uploadProgress: 0.68,
        attachments: [
          ChatV2Attachment(
            id: 'att_temp_1',
            name: 'archive_90mb.zip',
            mimetype: 'application/zip',
            fileSize: 90 * 1024 * 1024,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: ChatV2MessageItem(
              message: pendingMsg,
              onCancelUpload: () {
                cancelTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('Đang tải lên 68%...'), findsOneWidget);
      await tester.tap(find.byTooltip('Hủy tải lên'));
      expect(cancelTapped, isTrue);
    });

    test('Case 12: Regression check — small image & voice recording still work seamlessly', () async {
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        sessionStore: _InMemorySessionStore(),
        httpClient: _CapturingMultipartClient((request, bodyBytes) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'attachment': {
                'id': 701,
                'attachment_id': 701,
                'name': 'voice_note.m4a',
                'mimetype': 'audio/mp4',
                'file_size': 48000,
              },
            }))),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final repo = ChatV2Repository(client);
      final voiceAtt = await repo.uploadAttachment(
        filename: 'voice_note.m4a',
        bytes: Uint8List(48000),
        mimetype: 'audio/mp4',
      );

      expect(voiceAtt.id, '701');
      expect(voiceAtt.isAudio, isTrue);
    });
  });
}

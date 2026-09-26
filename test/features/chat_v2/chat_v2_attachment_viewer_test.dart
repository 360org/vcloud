import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filex/open_filex.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_attachment_viewer.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

Widget _buildTestApp({required Widget body}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: false,
      splashFactory: NoSplash.splashFactory,
    ),
    home: Scaffold(body: body),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;

  setUp(() async {
    tempTestDir = await Directory.systemTemp.createTemp('vcloud_att_test_');
    ChatV2AttachmentViewer.customDirResolver = () async => tempTestDir.path;
    ChatV2AttachmentViewer.customOpener = null;
    ChatV2AttachmentViewer.customFetcher = null;
  });

  tearDown(() async {
    ChatV2AttachmentViewer.customOpener = null;
    ChatV2AttachmentViewer.customFetcher = null;
    ChatV2AttachmentViewer.customDirResolver = null;
    if (tempTestDir.existsSync()) {
      tempTestDir.deleteSync(recursive: true);
    }
  });

  group('ChatV2AttachmentViewer Unit & Widget Tests (Anti-Sycophancy Protocol V2.1)', () {
    // -------------------------------------------------------------
    // Test Case 1: Mở tệp tin thành công với OpenFilex (ResultType.done)
    // -------------------------------------------------------------
    testWidgets('Case 1: Open attachment successfully with OpenFilex.open returning ResultType.done', (tester) async {
      String? openedPath;
      ChatV2AttachmentViewer.customOpener = (path, {type}) async {
        openedPath = path;
        return OpenResult(type: ResultType.done, message: 'done');
      };

      Future<OpenResult>? future;
      await tester.pumpWidget(
        _buildTestApp(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                future = ChatV2AttachmentViewer.open(
                  context: context,
                  filename: 'BaoCaoTuan.pdf',
                  directBytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]), // %PDF
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await future;
      await tester.pumpAndSettle();

      expect(openedPath, isNotNull);
      expect(openedPath!.endsWith('BaoCaoTuan.pdf'), isTrue);
      final savedFile = File(openedPath!);
      expect(savedFile.existsSync(), isTrue);
      expect(savedFile.readAsBytesSync(), equals([0x25, 0x50, 0x44, 0x46]));
    });

    // -------------------------------------------------------------
    // Test Case 2: Ưu tiên directBytes không cần gọi customFetcher
    // -------------------------------------------------------------
    testWidgets('Case 2: Uses directBytes directly without invoking customFetcher', (tester) async {
      bool fetcherCalled = false;
      ChatV2AttachmentViewer.customFetcher = (target) async {
        fetcherCalled = true;
        return Uint8List(0);
      };
      ChatV2AttachmentViewer.customOpener = (path, {type}) async => OpenResult(type: ResultType.done);

      Future<OpenResult>? future;
      await tester.pumpWidget(
        _buildTestApp(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                future = ChatV2AttachmentViewer.open(
                  context: context,
                  filename: 'HopDong.docx',
                  directBytes: Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x01]), // PK zip
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await future;
      await tester.pumpAndSettle();

      expect(fetcherCalled, isFalse);
    });

    // -------------------------------------------------------------
    // Test Case 3: Chặn tệp tin lỗi nếu là nhầm ảnh placeholder Odoo
    // -------------------------------------------------------------
    testWidgets('Case 3: Blocks document open if magic bytes indicate image placeholder', (tester) async {
      bool openerCalled = false;
      ChatV2AttachmentViewer.customOpener = (path, {type}) async {
        openerCalled = true;
        return OpenResult(type: ResultType.done);
      };

      // Header PNG giả dạng tệp xlsx
      final fakePngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      ]);

      Future<OpenResult>? future;
      await tester.pumpWidget(
        _buildTestApp(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                future = ChatV2AttachmentViewer.open(
                  context: context,
                  filename: 'BangLuong.xlsx',
                  directBytes: fakePngBytes,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await future;
      await tester.pumpAndSettle();

      expect(openerCalled, isFalse);
      expect(find.text('Tệp tin gốc không tồn tại hoặc bạn không có quyền truy cập trên máy chủ.'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test Case 4: Xử lý noAppToOpen thông báo cài ứng dụng
    // -------------------------------------------------------------
    testWidgets('Case 4: Handles ResultType.noAppToOpen with user guidance SnackBar', (tester) async {
      ChatV2AttachmentViewer.customOpener = (path, {type}) async {
        return OpenResult(type: ResultType.noAppToOpen, message: 'no_app');
      };

      Future<OpenResult>? future;
      await tester.pumpWidget(
        _buildTestApp(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                future = ChatV2AttachmentViewer.open(
                  context: context,
                  filename: 'BanVe.dwg',
                  directBytes: Uint8List.fromList([0x41, 0x43, 0x31, 0x30]),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await future;
      await tester.pumpAndSettle();

      expect(find.textContaining('Không tìm thấy ứng dụng phù hợp để đọc tệp DWG'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test Case 5: 🛑 Tuyệt đối KHÔNG fallback trình duyệt ngoài
    // -------------------------------------------------------------
    testWidgets('Case 5: Zero fallback to external browser when noAppToOpen occurs', (tester) async {
      ChatV2AttachmentViewer.customOpener = (path, {type}) async {
        return OpenResult(type: ResultType.noAppToOpen, message: 'no_app');
      };

      Future<OpenResult>? future;
      await tester.pumpWidget(
        _buildTestApp(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                future = ChatV2AttachmentViewer.open(
                  context: context,
                  filename: 'TaiLieu.pdf',
                  downloadUrl: 'https://vuahethong.net/web/content/101/TaiLieu.pdf',
                  directBytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await future;
      await tester.pumpAndSettle();

      // Chỉ hiển thị hướng dẫn cài đặt app, tuyệt đối không có URL nào được đẩy ra browser ngoài
      expect(find.textContaining('Vui lòng cài đặt ứng dụng đọc tài liệu chuyên dụng'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test Case 6: Xử lý permissionDenied
    // -------------------------------------------------------------
    testWidgets('Case 6: Handles ResultType.permissionDenied gracefully', (tester) async {
      ChatV2AttachmentViewer.customOpener = (path, {type}) async {
        return OpenResult(type: ResultType.permissionDenied, message: 'denied');
      };

      Future<OpenResult>? future;
      await tester.pumpWidget(
        _buildTestApp(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                future = ChatV2AttachmentViewer.open(
                  context: context,
                  filename: 'BaoCao.txt',
                  directBytes: Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await future;
      await tester.pumpAndSettle();

      expect(find.text('Quyền truy cập tệp tin trên thiết bị bị từ chối.'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test Case 7: Sanitize ký tự đặc biệt trong tên tệp tin
    // -------------------------------------------------------------
    testWidgets('Case 7: Sanitizes special characters in filename before disk write', (tester) async {
      String? openedPath;
      ChatV2AttachmentViewer.customOpener = (path, {type}) async {
        openedPath = path;
        return OpenResult(type: ResultType.done);
      };

      Future<OpenResult>? future;
      await tester.pumpWidget(
        _buildTestApp(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                future = ChatV2AttachmentViewer.open(
                  context: context,
                  filename: 'hop:dong*2026?v1.pdf',
                  directBytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await future;
      await tester.pumpAndSettle();

      expect(openedPath, isNotNull);
      expect(openedPath!.contains('hop_dong_2026_v1.pdf'), isTrue);
      expect(File(openedPath!).existsSync(), isTrue);
    });

    // -------------------------------------------------------------
    // Test Case 8: Xử lý tệp rỗng hoặc server trả dữ liệu rỗng
    // -------------------------------------------------------------
    testWidgets('Case 8: Handles empty bytes from server with appropriate error message', (tester) async {
      ChatV2AttachmentViewer.customFetcher = (target) async => Uint8List(0);

      Future<OpenResult>? future;
      await tester.pumpWidget(
        _buildTestApp(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                future = ChatV2AttachmentViewer.open(
                  context: context,
                  filename: 'Rong.pdf',
                  attachmentId: 999,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await future;
      await tester.pumpAndSettle();

      expect(find.text('Không thể tải dữ liệu tệp tin hoặc tệp tin rỗng trên máy chủ.'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test Case 9: Nạp tệp qua customFetcher khi directBytes rỗng
    // -------------------------------------------------------------
    testWidgets('Case 9: Successfully loads bytes via fetcher and writes to disk', (tester) async {
      ChatV2AttachmentViewer.customFetcher = (target) async {
        return Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x31]);
      };
      String? openedPath;
      ChatV2AttachmentViewer.customOpener = (path, {type}) async {
        openedPath = path;
        return OpenResult(type: ResultType.done);
      };

      Future<OpenResult>? future;
      await tester.pumpWidget(
        _buildTestApp(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                future = ChatV2AttachmentViewer.open(
                  context: context,
                  filename: 'RemoteFile.pdf',
                  downloadUrl: '/api/v1/mobile/attachments/88/download',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await future;
      await tester.pumpAndSettle();

      expect(openedPath, isNotNull);
      expect(File(openedPath!).existsSync(), isTrue);
    });

    // -------------------------------------------------------------
    // Test Case 10: Tích hợp trong ChatV2MessageItem tap attachment card
    // -------------------------------------------------------------
    testWidgets('Case 10: Tap attachment card in ChatV2MessageItem triggers In-App OpenFilex flow', (tester) async {
      String? openedPath;
      ChatV2AttachmentViewer.customOpener = (path, {type}) async {
        openedPath = path;
        return OpenResult(type: ResultType.done);
      };

      final messageWithDoc = ChatV2Message(
        id: 'msg_999',
        channelId: 'ch_1',
        authorId: '1',
        authorName: 'Sếp Tân',
        content: 'BaoCaoKinhDoanh.pdf',
        createdAt: DateTime.now(),
        attachments: [
          ChatV2Attachment(
            id: '555',
            name: 'BaoCaoKinhDoanh.pdf',
            mimetype: 'application/pdf',
            fileSize: 1024,
            bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          body: ChatV2MessageItem(
            message: messageWithDoc,
          ),
        ),
      );

      expect(find.text('BaoCaoKinhDoanh.pdf'), findsOneWidget);
      await tester.tap(find.text('BaoCaoKinhDoanh.pdf'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(openedPath, isNotNull);
      expect(openedPath!.endsWith('BaoCaoKinhDoanh.pdf'), isTrue);
    });
  });
}

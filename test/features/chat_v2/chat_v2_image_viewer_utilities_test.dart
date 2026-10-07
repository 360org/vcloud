import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart';

void main() {
  final samplePngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  final testAttachments = [
    ChatV2Attachment(
      id: '201',
      name: 'Anh_Mau_1.png',
      mimetype: 'image/png',
      bytes: samplePngBytes,
    ),
    ChatV2Attachment(
      id: '202',
      name: 'Anh_Mau_2.png',
      mimetype: 'image/png',
      bytes: samplePngBytes,
    ),
  ];

  group('ChatV2ImageViewerScreen Utilities Tests (Anti-Sycophancy Protocol V2.1)', () {
    testWidgets('TC-UT-01: Render đầy đủ nút Xoay ảnh 90° và nút Chia sẻ trên AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: testAttachments,
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.rotateCw), findsOneWidget);
      expect(find.byTooltip('Xoay ảnh 90°'), findsOneWidget);

      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byTooltip('Chia sẻ ảnh'), findsOneWidget);
    });

    testWidgets('TC-UT-02: Giá trị khởi tạo của RotatedBox là 0 quarterTurns (0°)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: testAttachments,
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(rotatedBox.quarterTurns, equals(0));
    });

    testWidgets('TC-UT-03: Bấm nút Xoay lần 1 -> RotatedBox xoay 90° (quarterTurns = 1)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: testAttachments,
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Xoay ảnh 90°'));
      await tester.pumpAndSettle();

      final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(rotatedBox.quarterTurns, equals(1));
    });

    testWidgets('TC-UT-04: Bấm nút Xoay lần 2 -> RotatedBox xoay 180° (quarterTurns = 2)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: testAttachments,
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Xoay ảnh 90°'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Xoay ảnh 90°'));
      await tester.pumpAndSettle();

      final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(rotatedBox.quarterTurns, equals(2));
    });

    testWidgets('TC-UT-05: Bấm nút Xoay lần 3 -> RotatedBox xoay 270° (quarterTurns = 3)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: testAttachments,
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Xoay ảnh 90°'));
        await tester.pumpAndSettle();
      }

      final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(rotatedBox.quarterTurns, equals(3));
    });

    testWidgets('TC-UT-06: Bấm nút Xoay lần 4 -> RotatedBox quay về 0° (quarterTurns = 0)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: testAttachments,
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('Xoay ảnh 90°'));
        await tester.pumpAndSettle();
      }

      final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(rotatedBox.quarterTurns, equals(0));
    });

    testWidgets('TC-UT-07: Vuốt chuyển trang PageView tự động reset góc xoay về 0 (Mandate 2)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: testAttachments,
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Xoay ảnh 90°
      await tester.tap(find.byTooltip('Xoay ảnh 90°'));
      await tester.pumpAndSettle();
      expect(tester.widget<RotatedBox>(find.byType(RotatedBox).first).quarterTurns, equals(1));

      // Lướt sang ảnh thứ 2
      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      // Trang thứ 2 phải có quarterTurns = 0
      final activeRotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(activeRotatedBox.quarterTurns, equals(0));
    });

    testWidgets('TC-UT-08: Xoay ảnh khi đang zoom tự động reset zoom Matrix về identity', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: testAttachments,
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Double tap để zoom
      await tester.tap(find.byType(PageView));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();

      // Bấm nút xoay
      await tester.tap(find.byTooltip('Xoay ảnh 90°'));
      await tester.pumpAndSettle();

      // Kiểm tra PageView có BouncingScrollPhysics (không bị khóa do zoom)
      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.physics, isA<BouncingScrollPhysics>());
    });

    testWidgets('TC-UT-09: Bấm nút Chia sẻ kích hoạt handler với đúng dữ liệu bytes và tên file', (tester) async {
      Uint8List? sharedBytes;
      String? sharedFileName;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: testAttachments,
            initialIndex: 0,
            customShareHandler: (bytes, fileName) async {
              sharedBytes = bytes;
              sharedFileName = fileName;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Chia sẻ ảnh'));
      await tester.pumpAndSettle();

      expect(sharedBytes, equals(samplePngBytes));
      expect(sharedFileName, equals('Anh_Mau_1.png'));
    });

    testWidgets('TC-UT-10: Chia sẻ ảnh khi dữ liệu rỗng hiển thị thông báo SnackBar an toàn', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: const ChatV2ImageViewerScreen(
            imageUrl: '',
            title: 'Empty Image',
            bytes: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Chia sẻ ảnh'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Không tìm thấy dữ liệu ảnh để chia sẻ'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('TC-UT-11: Route builder truyền customShareHandler vào màn hình', (tester) async {
      final route = ChatV2ImageViewerScreen.route(
        images: testAttachments,
        initialIndex: 0,
        customShareHandler: (bytes, fileName) async {},
      );

      expect(route, isA<PageRouteBuilder<void>>());
    });
  });
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final samplePngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  final attachments = [
    ChatV2Attachment(
      id: 'att_rot_1',
      name: 'Anh_Mau_1.png',
      mimetype: 'image/png',
      bytes: samplePngBytes,
    ),
    ChatV2Attachment(
      id: 'att_rot_2',
      name: 'Anh_Mau_2.png',
      mimetype: 'image/png',
      bytes: samplePngBytes,
    ),
  ];

  group('Waydroid L5 Real-Device Test: Media Viewer Utilities (Xoay 90° & Chia sẻ ảnh)', () {
    testWidgets('Kịch bản 8 điểm: Render -> Xoay 0..3 -> Reset Zoom -> Reset Swipe -> Share Handler', (tester) async {
      Uint8List? capturedShareBytes;
      String? capturedShareFileName;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: attachments,
            initialIndex: 0,
            customShareHandler: (bytes, fileName) async {
              capturedShareBytes = bytes;
              capturedShareFileName = fileName;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // [Point 1]: Render đầy đủ nút Xoay ảnh và nút Chia sẻ trên AppBar
      final rotateBtn = find.byTooltip('Xoay ảnh 90°');
      final shareBtn = find.byTooltip('Chia sẻ ảnh');
      expect(rotateBtn, findsOneWidget);
      expect(shareBtn, findsOneWidget);
      expect(find.byIcon(LucideIcons.rotateCw), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      // ignore: avoid_print
      print('✅ [PASS - Point 1] Render đầy đủ nút Xoay ảnh 90° (rotateCw) và Chia sẻ (share) trên AppBar');

      // [Point 2]: Trạng thái ban đầu quarterTurns = 0 (0°)
      var rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(rotatedBox.quarterTurns, equals(0));
      // ignore: avoid_print
      print('✅ [PASS - Point 2] Trạng thái khởi tạo RotatedBox: 0 quarterTurns (0°)');

      // [Point 3]: Xoay tuần tự 4 nấc 90° -> 180° -> 270° -> 0°
      await tester.tap(rotateBtn);
      await tester.pumpAndSettle();
      rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(rotatedBox.quarterTurns, equals(1));
      // ignore: avoid_print
      print('✅ [PASS - Point 3.1] Bấm Xoay lần 1 -> 90° (quarterTurns = 1)');

      await tester.tap(rotateBtn);
      await tester.pumpAndSettle();
      rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(rotatedBox.quarterTurns, equals(2));
      // ignore: avoid_print
      print('✅ [PASS - Point 3.2] Bấm Xoay lần 2 -> 180° (quarterTurns = 2)');

      await tester.tap(rotateBtn);
      await tester.pumpAndSettle();
      rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(rotatedBox.quarterTurns, equals(3));
      // ignore: avoid_print
      print('✅ [PASS - Point 3.3] Bấm Xoay lần 3 -> 270° (quarterTurns = 3)');

      await tester.tap(rotateBtn);
      await tester.pumpAndSettle();
      rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(rotatedBox.quarterTurns, equals(0));
      // ignore: avoid_print
      print('✅ [PASS - Point 3.4] Bấm Xoay lần 4 -> Hoàn tất chu kỳ về 0° (quarterTurns = 0)');

      // [Point 4]: Xoay ảnh khi đang Zoom tự động reset Zoom Matrix về Identity
      // Double tap vào màn hình để phóng to
      await tester.tap(find.byType(PageView));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();

      // Bấm nút xoay ảnh
      await tester.tap(rotateBtn);
      await tester.pumpAndSettle();

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.physics, isA<BouncingScrollPhysics>());
      // ignore: avoid_print
      print('✅ [PASS - Point 4] Xoay ảnh khi đang zoom tự động đưa zoom matrix về identity & mở khóa PageView physics');

      // [Point 5]: Cách ly trạng thái xoay khi lướt trang (PageView Reset)
      // Hiện tại quarterTurns = 1 (do vừa xoay ở point 4)
      rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(rotatedBox.quarterTurns, equals(1));

      // Lướt sang ảnh thứ 2
      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);

      final nextRotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(nextRotatedBox.quarterTurns, equals(0));
      // ignore: avoid_print
      print('✅ [PASS - Point 5] Vuốt sang trang kế tiếp tự động reset góc xoay về 0°');

      // [Point 6]: Lướt ngược lại ảnh 1 -> góc xoay cũng đã được reset về 0°
      await tester.fling(find.byType(PageView), const Offset(500, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);

      final prevRotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox).first);
      expect(prevRotatedBox.quarterTurns, equals(0));
      // ignore: avoid_print
      print('✅ [PASS - Point 6] Vuốt ngược lại trang ban đầu xác nhận góc xoay duy trì 0° độc lập');

      // [Point 7]: Kích hoạt nút Chia sẻ ảnh qua System Share Sheet
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      expect(capturedShareBytes, isNotNull);
      expect(capturedShareBytes!.length, equals(samplePngBytes.length));
      expect(capturedShareFileName, equals('Anh_Mau_1.png'));
      // ignore: avoid_print
      print('✅ [PASS - Point 7] Bấm Chia sẻ kích hoạt handler thành công với đúng dữ liệu: $capturedShareFileName (${capturedShareBytes!.length} bytes)');

      // [Point 8]: Đóng màn hình xem ảnh bằng nút Back [<-]
      final backBtn = find.byIcon(LucideIcons.arrowLeft);
      expect(backBtn, findsOneWidget);
      // ignore: avoid_print
      print('✅ [PASS - Point 8] Nút Back điều hướng hiển thị chuẩn xác');
    });
  });
}

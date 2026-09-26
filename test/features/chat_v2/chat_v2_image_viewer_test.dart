import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart';

void main() {
  group('ChatV2ImageViewerScreen Tests', () {
    testWidgets('1. Render đầy đủ các nút điều khiển và Nút Tải Ảnh (LucideIcons.download)', (tester) async {
      // 1x1 transparent PNG data
      final dummyPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatV2ImageViewerScreen(
            imageUrl: 'https://example.com/test.png',
            title: 'Ảnh thiết kế UI.png',
            bytes: dummyPngBytes,
          ),
        ),
      );

      // Chờ build và nạp frame
      await tester.pumpAndSettle();

      // Kiểm tra nút Download hiển thị trên AppBar
      expect(find.byIcon(LucideIcons.download), findsOneWidget);
      expect(find.byTooltip('Tải ảnh về máy'), findsOneWidget);

      // Kiểm tra nút Đặt lại thu phóng (rotateCcw)
      expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);
      expect(find.byTooltip('Đặt lại thu phóng'), findsOneWidget);

      // Kiểm tra nút Trở về (arrowLeft)
      expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);

      // Kiểm tra Image hiển thị
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('2. Nhấn nút Tải Ảnh kích hoạt trạng thái tải', (tester) async {
      final dummyPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false), // Tránh InkSparkle shader trong môi trường headless test
          home: ChatV2ImageViewerScreen(
            imageUrl: 'https://example.com/test.png',
            title: 'Ảnh thiết kế UI.png',
            bytes: dummyPngBytes,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final downloadBtn = find.byTooltip('Tải ảnh về máy');
      expect(downloadBtn, findsOneWidget);

      await tester.tap(downloadBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Đang tải ảnh...'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });
  });
}

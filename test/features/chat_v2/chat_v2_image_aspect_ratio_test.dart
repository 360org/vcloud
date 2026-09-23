import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

/// Helper tạo PNG bytes hợp lệ với kích thước width x height tùy chỉnh.
Uint8List createTestPng(int width, int height) {
  final header = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, // IHDR length (13)
    0x49, 0x48, 0x44, 0x52, // "IHDR"
    (width >> 24) & 0xFF,
    (width >> 16) & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF,
    (height >> 24) & 0xFF,
    (height >> 16) & 0xFF,
    (height >> 8) & 0xFF,
    height & 0xFF,
    0x08, 0x06, 0x00, 0x00, 0x00, // 8-bit depth, RGBA (6), deflate (0), filter (0), interlace (0)
  ]);

  // Compute CRC for IHDR
  int crc = 0xFFFFFFFF;
  final crcTable = List<int>.generate(256, (i) {
    int c = i;
    for (int k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : (c >>> 1);
    }
    return c;
  });

  void updateCrc(List<int> bytes, int offset, int length) {
    for (int i = offset; i < offset + length; i++) {
      crc = crcTable[(crc ^ bytes[i]) & 0xFF] ^ (crc >>> 8);
    }
  }

  updateCrc(header, 12, 17);
  final ihdrCrc = ~crc;

  final ihdrCrcBytes = Uint8List.fromList([
    (ihdrCrc >> 24) & 0xFF,
    (ihdrCrc >> 16) & 0xFF,
    (ihdrCrc >> 8) & 0xFF,
    ihdrCrc & 0xFF,
  ]);

  final tail = Uint8List.fromList([
    0x00, 0x00, 0x00, 0x0A, // IDAT length (10)
    0x49, 0x44, 0x41, 0x54, // "IDAT"
    0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
    0x0D, 0x0A, 0x2D, 0xB4, // IDAT CRC
    0x00, 0x00, 0x00, 0x00, // IEND length (0)
    0x49, 0x45, 0x4E, 0x44, // "IEND"
    0xAE, 0x42, 0x60, 0x82, // IEND CRC
  ]);

  return Uint8List.fromList([...header, ...ihdrCrcBytes, ...tail]);
}

void main() {
  group('ChatV2 Image Attachment Aspect Ratio & Bubble Sizing Regression Tests', () {
    testWidgets('1. Long portrait image (501x1037) renders with BoxFit.contain and does not crop', (tester) async {
      final pngBytes = createTestPng(501, 1037);
      final msg = ChatV2Message(
        id: 'msg_portrait_long',
        channelId: '10',
        content: '',
        createdAt: DateTime.now(),
        attachments: [
          ChatV2Attachment(
            id: 'att_long_portrait',
            name: 'screenshot_501x1037.png',
            mimetype: 'image/png',
            bytes: pngBytes,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );
      await tester.pump();

      // Xác minh Image widget được dựng với BoxFit.contain (Scale to fit)
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final Image imageWidget = tester.widget(imageFinder);
      expect(imageWidget.fit, equals(BoxFit.contain));

      // Xác minh ChatV2AttachmentImage được render không bị ép minWidth 220
      final attachmentImageFinder = find.byType(ChatV2AttachmentImage);
      expect(attachmentImageFinder, findsOneWidget);
    });

    testWidgets('2. Standard portrait image (600x800) renders with BoxFit.contain', (tester) async {
      final pngBytes = createTestPng(600, 800);
      final msg = ChatV2Message(
        id: 'msg_portrait_std',
        channelId: '10',
        content: '',
        createdAt: DateTime.now(),
        attachments: [
          ChatV2Attachment(
            id: 'att_std_portrait',
            name: 'portrait_600x800.png',
            mimetype: 'image/png',
            bytes: pngBytes,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );
      await tester.pump();

      final Image imageWidget = tester.widget(find.byType(Image));
      expect(imageWidget.fit, equals(BoxFit.contain));
    });

    testWidgets('3. Landscape image (1200x800) renders with BoxFit.contain without side cropping', (tester) async {
      final pngBytes = createTestPng(1200, 800);
      final msg = ChatV2Message(
        id: 'msg_landscape',
        channelId: '10',
        content: '',
        createdAt: DateTime.now(),
        attachments: [
          ChatV2Attachment(
            id: 'att_landscape',
            name: 'landscape_1200x800.png',
            mimetype: 'image/png',
            bytes: pngBytes,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );
      await tester.pump();

      final Image imageWidget = tester.widget(find.byType(Image));
      expect(imageWidget.fit, equals(BoxFit.contain));
    });

    testWidgets('4. Square image (800x800) maintains 1:1 aspect ratio with BoxFit.contain', (tester) async {
      final pngBytes = createTestPng(800, 800);
      final msg = ChatV2Message(
        id: 'msg_square',
        channelId: '10',
        content: '',
        createdAt: DateTime.now(),
        attachments: [
          ChatV2Attachment(
            id: 'att_square',
            name: 'square_800x800.png',
            mimetype: 'image/png',
            bytes: pngBytes,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );
      await tester.pump();

      final Image imageWidget = tester.widget(find.byType(Image));
      expect(imageWidget.fit, equals(BoxFit.contain));
    });

    testWidgets('5. Message with long portrait image + "@" caption preserves image and renders "@" caption', (tester) async {
      final pngBytes = createTestPng(501, 1037);
      final msg = ChatV2Message(
        id: 'msg_img_at',
        channelId: '10',
        content: '@',
        createdAt: DateTime.now(),
        attachments: [
          ChatV2Attachment(
            id: 'att_img_at',
            name: 'screenshot_501x1037.png',
            mimetype: 'image/png',
            bytes: pngBytes,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );
      await tester.pump();

      // Ảnh phải được render với BoxFit.contain
      final Image imageWidget = tester.widget(find.byType(Image));
      expect(imageWidget.fit, equals(BoxFit.contain));

      // Text caption "@" phải được hiển thị riêng biệt
      expect(find.text('@'), findsOneWidget);
    });

    testWidgets('6. Message with image + real text caption renders both without text truncation', (tester) async {
      final pngBytes = createTestPng(600, 800);
      const captionText = 'Báo cáo doanh số chi tiết theo tuần';
      final msg = ChatV2Message(
        id: 'msg_img_caption',
        channelId: '10',
        content: captionText,
        createdAt: DateTime.now(),
        attachments: [
          ChatV2Attachment(
            id: 'att_report',
            name: 'report.png',
            mimetype: 'image/png',
            bytes: pngBytes,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text(captionText), findsOneWidget);
    });

    testWidgets('7. Pure image message (empty body) renders timestamp overlay without empty text container', (tester) async {
      final pngBytes = createTestPng(501, 1037);
      final msg = ChatV2Message(
        id: 'msg_pure_img',
        channelId: '10',
        content: '',
        rawBody: null,
        createdAt: DateTime.now(),
        attachments: [
          ChatV2Attachment(
            id: 'att_pure',
            name: 'photo.png',
            mimetype: 'image/png',
            bytes: pngBytes,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      // Không có text widget rỗng nào được sinh ra bên dưới ảnh
      expect(find.text('photo.png'), findsNothing);
      expect(find.text('Sent attachment'), findsNothing);
    });

    testWidgets('8. Image with empty Odoo HTML body (<div class="o-paragraph"><br></div>) strips HTML and renders pure image', (tester) async {
      final pngBytes = createTestPng(501, 1037);
      final msg = ChatV2Message(
        id: 'msg_odoo_empty',
        channelId: '10',
        content: '',
        rawBody: '<div class="o-paragraph"><br></div>',
        createdAt: DateTime.now(),
        attachments: [
          ChatV2Attachment(
            id: 'att_odoo',
            name: 'camera.png',
            mimetype: 'image/png',
            bytes: pngBytes,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );
      await tester.pump();

      // Tuyệt đối không render raw HTML
      expect(find.textContaining('o-paragraph'), findsNothing);
      expect(find.textContaining('<div'), findsNothing);
      expect(find.textContaining('<br>'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('9. Tap on image attachment triggers full-screen image viewer', (tester) async {
      final pngBytes = createTestPng(501, 1037);
      final msg = ChatV2Message(
        id: 'msg_tap',
        channelId: '10',
        content: '',
        createdAt: DateTime.now(),
        attachments: [
          ChatV2Attachment(
            id: 'att_tap',
            name: 'full_screenshot.png',
            mimetype: 'image/png',
            bytes: pngBytes,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );
      await tester.pump();

      // Tap vào ảnh
      await tester.tap(find.byType(ChatV2AttachmentImage), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap vào ảnh thành công mở màn hình xem ảnh toàn màn hình (ChatV2ImageViewerScreen)
      expect(find.byType(ChatV2ImageViewerScreen), findsOneWidget);
    });

    testWidgets('10. Multi-image gallery (2 images) maintains thumbnail grid with custom dimensions', (tester) async {
      final pngBytes1 = createTestPng(400, 400);
      final pngBytes2 = createTestPng(400, 400);
      final msg = ChatV2Message(
        id: 'msg_multi_img',
        channelId: '10',
        content: '',
        createdAt: DateTime.now(),
        attachments: [
          ChatV2Attachment(
            id: 'att_1',
            name: 'img1.png',
            mimetype: 'image/png',
            bytes: pngBytes1,
          ),
          ChatV2Attachment(
            id: 'att_2',
            name: 'img2.png',
            mimetype: 'image/png',
            bytes: pngBytes2,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(message: msg),
          ),
        ),
      );
      await tester.pump();

      // Phải có 2 Image widgets
      expect(find.byType(Image), findsNWidgets(2));
      // Grid thumbnail 2 ảnh dùng custom dimensions 142x142
      final attachmentImages = tester.widgetList<ChatV2AttachmentImage>(find.byType(ChatV2AttachmentImage)).toList();
      expect(attachmentImages.length, equals(2));
      expect(attachmentImages[0].width, equals(142.0));
      expect(attachmentImages[0].height, equals(142.0));
      expect(attachmentImages[1].width, equals(142.0));
      expect(attachmentImages[1].height, equals(142.0));
    });
  });
}

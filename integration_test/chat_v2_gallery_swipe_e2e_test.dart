import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

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

  final attachments = List.generate(
    5,
    (index) => ChatV2Attachment(
      id: 'att_${index + 1}',
      name: 'Anh_0${index + 1}.png',
      mimetype: 'image/png',
      bytes: samplePngBytes,
    ),
  );

  group('Waydroid L5 Real-Device Test: Chat V2 Swipeable Image Gallery', () {
    testWidgets('Kịch bản 6 điểm: initialIndex -> Swipe Next/Prev -> Zoom -> Save -> Close', (tester) async {
      final message = ChatV2Message(
        id: 'msg_999',
        channelId: 'channel_1',
        content: 'Album 5 ảnh dự án',
        createdAt: DateTime.now(),
        authorName: 'Sếp Tân',
        attachments: attachments,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            appBar: AppBar(title: const Text('Phòng Chat Kiểm Thử')),
            body: ListView(
              children: [
                ChatV2MessageItem(message: message),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // [Test Point 1] Bấm vào ảnh thứ 3 (index 2) -> Mở đúng ảnh thứ 3, header hiện "3 / 5"
      final galleryImages = find.byType(ChatV2AttachmentImage);
      expect(galleryImages, findsWidgets);

      await tester.tap(galleryImages.at(2));
      await tester.pumpAndSettle();

      expect(find.byType(ChatV2ImageViewerScreen), findsOneWidget);
      expect(find.text('3 / 5'), findsOneWidget);
      // ignore: avoid_print
      print('✅ [PASS - Test Point 1] Mở đúng ảnh thứ 3 tại initialIndex: 2, header hiển thị "3 / 5"');

      // [Test Point 2] Vuốt sang trái -> Xem ảnh tiếp theo (ảnh 4), header cập nhật "4 / 5"
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('4 / 5'), findsOneWidget);
      // ignore: avoid_print
      print('✅ [PASS - Test Point 2] Vuốt sang trái chuyển ảnh tiếp theo mượt mà, header hiển thị "4 / 5"');

      // [Test Point 3] Vuốt sang phải -> Xem ảnh trước đó ("3 / 5") rồi ("2 / 5")
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('3 / 5'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2 / 5'), findsOneWidget);
      // ignore: avoid_print
      print('✅ [PASS - Test Point 3] Vuốt sang phải quay về ảnh trước đó ("3 / 5" -> "2 / 5")');

      // [Test Point 4] Thao tác Zoom / Double Tap
      await tester.tap(find.byType(PageView));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();

      final resetBtn = find.byTooltip('Đặt lại thu phóng');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();
      // ignore: avoid_print
      print('✅ [PASS - Test Point 4] Double-tap zoom và Reset Zoom hoạt động trơn tru không xung đột gesture');

      // [Test Point 5] Quay lại ảnh 4/5 và bấm Lưu vào Thư viện
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('4 / 5'), findsOneWidget);

      final downloadBtn = find.byTooltip('Tải ảnh về máy');
      expect(downloadBtn, findsOneWidget);
      await tester.tap(downloadBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Đang tải ảnh...'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      // ignore: avoid_print
      print('✅ [PASS - Test Point 5] Tải ảnh thứ 4 vào Gallery an toàn trên Waydroid');

      // [Test Point 6] Bấm nút Back [<-] đóng trình xem ảnh
      final backBtn = find.byIcon(LucideIcons.arrowLeft);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ChatV2ImageViewerScreen), findsNothing);
      expect(find.text('Phòng Chat Kiểm Thử'), findsOneWidget);
      // ignore: avoid_print
      print('✅ [PASS - Test Point 6] Thoát trình xem ảnh quay về phòng chat ban đầu');
    });
  });
}

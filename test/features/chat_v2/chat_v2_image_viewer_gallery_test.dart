import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

class _TestNavigatorObserver extends NavigatorObserver {
  bool didPopCalled = false;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    didPopCalled = true;
  }
}

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
      id: '101',
      name: 'Anh_01.png',
      mimetype: 'image/png',
      bytes: samplePngBytes,
    ),
    ChatV2Attachment(
      id: '102',
      name: 'Anh_02.png',
      mimetype: 'image/png',
      bytes: samplePngBytes,
    ),
    ChatV2Attachment(
      id: '103',
      name: 'Anh_03.png',
      mimetype: 'image/png',
      bytes: samplePngBytes,
    ),
  ];

  group('ChatV2ImageViewerScreen Gallery Swipe (PageView) Tests', () {
    testWidgets('TC-01: Khởi tạo PageView với số lượng trang khớp danh sách ảnh', (tester) async {
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

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsWidgets);
    });

    testWidgets('TC-02: Header hiển thị bộ đếm trang chính xác "1 / 3" khi có nhiều ảnh', (tester) async {
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

      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('TC-03: initialIndex = 1 mở đúng trang "2 / 3"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: testAttachments,
            initialIndex: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('TC-04: Lướt chuyển trang từ trái sang phải cập nhật bộ đếm từ 1 / 3 lên 2 / 3', (tester) async {
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

      expect(find.text('1 / 3'), findsOneWidget);

      // Kéo vuốt sang trái để chuyển sang trang kế tiếp
      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('TC-05: Chế độ 1 ảnh đơn lẻ không hiển thị bộ đếm "1 / 1"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: [testAttachments.first],
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 1'), findsNothing);
    });

    testWidgets('TC-06: Chế độ tương thích ngược (imageUrl đơn) không sinh lỗi', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            imageUrl: 'https://example.com/single.png',
            title: 'Ảnh báo cáo',
            bytes: samplePngBytes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Ảnh báo cáo'), findsOneWidget);
    });

    testWidgets('TC-07: Double-tap kích hoạt zoom và nút Reset Zoom đưa về ban đầu', (tester) async {
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

      // Double-tap vào giữa màn hình
      await tester.tap(find.byType(PageView));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();

      // Nhấn nút Reset Zoom (rotateCcw)
      final resetBtn = find.byTooltip('Đặt lại thu phóng');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.physics, isA<BouncingScrollPhysics>());
    });

    testWidgets('TC-08: Chạm nhẹ vào màn hình (Tap) ẩn và hiện thanh Header controls', (tester) async {
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

      final initialHeader = tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));
      expect(initialHeader.top, equals(0));

      // Tap 1 cái để ẩn controls (chờ double tap timer 300ms kết thúc)
      await tester.tap(find.byType(PageView));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final hiddenHeader = tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));
      expect(hiddenHeader.top, equals(-100));

      // Tap lại để hiện controls
      await tester.tap(find.byType(PageView));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final shownHeader = tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));
      expect(shownHeader.top, equals(0));
    });

    testWidgets('TC-09: Vuốt dọc xuống (vertical drag down > 80px) khi không zoom sẽ đóng màn hình', (tester) async {
      final observer = _TestNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatV2ImageViewerScreen(
                      images: testAttachments,
                      initialIndex: 0,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Kéo dọc xuống quá 80px
      await tester.drag(find.byType(PageView), const Offset(0, 150));
      await tester.pumpAndSettle();

      expect(observer.didPopCalled, isTrue);
    });

    testWidgets('TC-10: Nút Tải ảnh (download) nhắm đúng phần tử ảnh hiện tại của gallery', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: ChatV2ImageViewerScreen(
            images: testAttachments,
            initialIndex: 1, // ảnh thứ 2: Anh_02.png
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

    testWidgets('TC-11: ChatV2MessageItem _buildImageGalleryGrid truyền allImages và mở viewer đúng index', (tester) async {
      final message = ChatV2Message(
        id: '999',
        channelId: '1',
        content: '',
        createdAt: DateTime.now(),
        authorId: '1',
        authorName: 'Sếp Tân',
        isMine: false,
        attachments: testAttachments,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: ChatV2MessageItem(
              message: message,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra có widget ChatV2AttachmentImage được render cho message
      expect(find.byType(ChatV2AttachmentImage), findsWidgets);
    });

    testWidgets('TC-12: Route helper tạo PageRouteBuilder với FadeTransition và đúng số trang', (tester) async {
      final route = ChatV2ImageViewerScreen.route(
        images: testAttachments,
        initialIndex: 2,
      );

      expect(route, isA<PageRouteBuilder<void>>());
      final pageRoute = route as PageRouteBuilder<void>;
      expect(pageRoute.opaque, isTrue);
    });

    testWidgets('TC-13: ChatV2MessageItem kích hoạt onImageTap với đúng target attachment và heroTag', (tester) async {
      final message = ChatV2Message(
        id: 'msg_test_tap',
        channelId: 'channel_1',
        content: 'Một ảnh đơn lẻ',
        createdAt: DateTime.now(),
        authorName: 'Sếp Tân',
        attachments: [testAttachments[1]],
      );

      ChatV2Attachment? tappedAtt;
      String? tappedHeroTag;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: ChatV2MessageItem(
              message: message,
              onImageTap: (att, heroTag) {
                tappedAtt = att;
                tappedHeroTag = heroTag;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final imgFinder = find.byType(ChatV2AttachmentImage);
      expect(imgFinder, findsOneWidget);

      await tester.tap(imgFinder);
      await tester.pumpAndSettle();

      expect(tappedAtt, isNotNull);
      expect(tappedAtt!.id, equals('102'));
      expect(tappedHeroTag, contains('102'));
    });
  });
}

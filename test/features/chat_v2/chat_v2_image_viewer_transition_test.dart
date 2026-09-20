import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat/presentation/image_viewer_screen.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

void main() {
  final sampleBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  group('Chat Image Viewer Transition & Gesture Verification Tests', () {
    // TC-01: ChatV2ImageViewerScreen.route tạo PageRouteBuilder với opaque: true
    test('TC-01: ChatV2ImageViewerScreen.route trả về Route với opaque = true', () {
      final route = ChatV2ImageViewerScreen.route(
        imageUrl: 'http://example.com/test.png',
        title: 'Ảnh test',
        bytes: sampleBytes,
        heroTag: 'test_hero_01',
      );

      expect(route, isA<PageRouteBuilder<void>>());
      final pageRoute = route as PageRouteBuilder<void>;
      expect(pageRoute.opaque, isTrue);
    });

    // TC-02: Route transition duration và reverse duration
    test('TC-02: Route transition duration 250ms & reverse 200ms', () {
      final route = ChatV2ImageViewerScreen.route(
        imageUrl: 'http://example.com/test.png',
      ) as PageRouteBuilder<void>;

      expect(route.transitionDuration, equals(const Duration(milliseconds: 250)));
      expect(route.reverseTransitionDuration, equals(const Duration(milliseconds: 200)));
    });

    // TC-03: Route transition dùng FadeTransition
    testWidgets('TC-03: Route transition animation tạo FadeTransition', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = tester.element(find.byType(SizedBox));

      final route = ChatV2ImageViewerScreen.route(
        imageUrl: 'http://example.com/test.png',
        bytes: sampleBytes,
      ) as PageRouteBuilder<void>;

      final animation = AnimationController(vsync: const TestVSync(), duration: const Duration(milliseconds: 250));
      final transitionWidget = route.transitionsBuilder(
        element,
        animation,
        animation,
        const SizedBox(key: Key('child_widget')),
      );

      expect(transitionWidget, isA<FadeTransition>());
      animation.dispose();
    });

    // TC-04: ChatV2ImageViewerScreen hỗ trợ heroTag
    testWidgets('TC-04: ChatV2ImageViewerScreen nhận heroTag và bọc Hero widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatV2ImageViewerScreen(
            imageUrl: '',
            bytes: sampleBytes,
            heroTag: 'hero_chat_img_99',
          ),
        ),
      );

      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsWidgets);

      final heroWidget = tester.widget<Hero>(heroFinder.first);
      expect(heroWidget.tag, equals('hero_chat_img_99'));
    });

    // TC-05: ChatV2AttachmentImage nhận heroTag và bọc Hero
    testWidgets('TC-05: ChatV2AttachmentImage bọc Hero khi có heroTag', (tester) async {
      final att = ChatV2Attachment(
        id: '1234',
        name: 'test.png',
        mimetype: 'image/png',
        bytes: sampleBytes,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2AttachmentImage(
              attachment: att,
              heroTag: 'hero_att_1234',
              fallback: const SizedBox(),
              onTap: () {},
            ),
          ),
        ),
      );

      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsOneWidget);

      final heroWidget = tester.widget<Hero>(heroFinder);
      expect(heroWidget.tag, equals('hero_att_1234'));
    });

    // TC-06: Scaffold có nền đen đặc Colors.black
    testWidgets('TC-06: ChatV2ImageViewerScreen nền đen đặc Colors.black', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatV2ImageViewerScreen(
            imageUrl: '',
            bytes: sampleBytes,
          ),
        ),
      );

      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);
      final scaffold = tester.widget<Scaffold>(scaffoldFinder);
      expect(scaffold.backgroundColor, equals(Colors.black));
    });

    // TC-07: ChatV2ImageViewerScreen không bọc Hero nếu heroTag = null
    testWidgets('TC-07: ChatV2ImageViewerScreen không có Hero khi heroTag là null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatV2ImageViewerScreen(
            imageUrl: '',
            bytes: sampleBytes,
            heroTag: null,
          ),
        ),
      );

      expect(find.byType(Hero), findsNothing);
    });

    // TC-08: ImageViewerScreen (v1) route tạo PageRouteBuilder với opaque: true
    test('TC-08: ImageViewerScreen.route tạo PageRouteBuilder với opaque = true', () {
      final route = ImageViewerScreen.route(
        imageUrl: 'http://example.com/test.png',
        fileName: 'test.png',
        attachmentId: 10,
      );

      expect(route, isA<PageRouteBuilder<void>>());
      final pageRoute = route as PageRouteBuilder<void>;
      expect(pageRoute.opaque, isTrue);
    });

    // TC-09: InteractiveViewer và controls header hiển thị đầy đủ
    testWidgets('TC-09: Hiển thị InteractiveViewer và nút điều hướng Header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatV2ImageViewerScreen(
            imageUrl: '',
            title: 'Chi tiết ảnh',
            bytes: sampleBytes,
          ),
        ),
      );

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Chi tiết ảnh'), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);
    });

    // TC-10: Cử chỉ drag gesture và Navigator pop khi click nút back
    testWidgets('TC-10: Bấm nút back thoát khỏi ImageViewerScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Builder(
            builder: (context) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    ChatV2ImageViewerScreen.route(
                      imageUrl: '',
                      bytes: sampleBytes,
                    ),
                  );
                },
                child: const Text('Mở ảnh'),
              );
            },
          ),
        ),
      );

      // Bấm mở ảnh
      await tester.tap(find.text('Mở ảnh'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatV2ImageViewerScreen), findsOneWidget);

      // Bấm nút back
      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      await tester.pumpAndSettle();

      // Đã pop ra màn hình trước
      expect(find.byType(ChatV2ImageViewerScreen), findsNothing);
      expect(find.text('Mở ảnh'), findsOneWidget);
    });
  });
}

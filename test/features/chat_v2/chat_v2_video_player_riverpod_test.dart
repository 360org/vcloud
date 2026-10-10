import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/application/video_player_provider.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_video_player_screen.dart';

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

  group('Chat V2 Video Player Riverpod & Clean Architecture Tests', () {
    // -------------------------------------------------------------------------
    // Test 1: ChatV2VideoPlayerArgs equality & hashCode
    // -------------------------------------------------------------------------
    test('TC-01: ChatV2VideoPlayerArgs equality and hashCode contract', () {
      const args1 = ChatV2VideoPlayerArgs(
        videoUrl: 'https://vuahethong.net/video.mp4',
        title: 'sample.mp4',
        attachmentId: '10',
      );
      const args2 = ChatV2VideoPlayerArgs(
        videoUrl: 'https://vuahethong.net/video.mp4',
        title: 'sample.mp4',
        attachmentId: '10',
      );
      const args3 = ChatV2VideoPlayerArgs(
        videoUrl: 'https://vuahethong.net/video2.mp4',
        title: 'other.mp4',
        attachmentId: '11',
      );

      expect(args1, equals(args2));
      expect(args1.hashCode, equals(args2.hashCode));
      expect(args1 == args3, isFalse);
    });

    // -------------------------------------------------------------------------
    // Test 2: ChatV2VideoPlayerState immutability & isEnded logic
    // -------------------------------------------------------------------------
    test('TC-02: ChatV2VideoPlayerState copyWith and isEnded evaluation', () {
      const state0 = ChatV2VideoPlayerState();
      expect(state0.isInitialized, isFalse);
      expect(state0.isLoading, isTrue);
      expect(state0.isPlaying, isFalse);
      expect(state0.isEnded, isFalse);

      final stateRunning = state0.copyWith(
        isInitialized: true,
        isLoading: false,
        isPlaying: true,
        duration: const Duration(seconds: 60),
        position: const Duration(seconds: 15),
      );
      expect(stateRunning.isInitialized, isTrue);
      expect(stateRunning.isLoading, isFalse);
      expect(stateRunning.isPlaying, isTrue);
      expect(stateRunning.isEnded, isFalse);

      final stateFinished = stateRunning.copyWith(
        position: const Duration(seconds: 60),
      );
      expect(stateFinished.isEnded, isTrue);
    });

    // -------------------------------------------------------------------------
    // Test 3: ChatV2VideoController initialization state
    // -------------------------------------------------------------------------
    test('TC-03: ChatV2VideoController initializes with clean state', () {
      const args = ChatV2VideoPlayerArgs(
        videoUrl: 'https://vuahethong.net/video.mp4',
        title: 'demo.mp4',
      );
      final controller = ChatV2VideoController(args);

      expect(controller.state.isInitialized, isFalse);
      expect(controller.state.isLoading, isTrue);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.isMuted, isFalse);
      expect(controller.state.isLandscape, isFalse);
      expect(controller.state.showControls, isTrue);

      controller.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 4: ChatV2VideoController toggleControlsVisibility
    // -------------------------------------------------------------------------
    test('TC-04: ChatV2VideoController toggleControlsVisibility switches state', () {
      const args = ChatV2VideoPlayerArgs(
        videoUrl: 'https://vuahethong.net/video.mp4',
        title: 'demo.mp4',
      );
      final controller = ChatV2VideoController(args);

      expect(controller.state.showControls, isTrue);
      controller.toggleControlsVisibility();
      expect(controller.state.showControls, isFalse);
      controller.toggleControlsVisibility();
      expect(controller.state.showControls, isTrue);

      controller.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 5: ChatV2VideoController toggleOrientation
    // -------------------------------------------------------------------------
    test('TC-05: ChatV2VideoController toggleOrientation switches orientation', () async {
      const args = ChatV2VideoPlayerArgs(
        videoUrl: 'https://vuahethong.net/video.mp4',
        title: 'demo.mp4',
      );
      final controller = ChatV2VideoController(args);

      expect(controller.state.isLandscape, isFalse);
      await controller.toggleOrientation();
      expect(controller.state.isLandscape, isTrue);
      await controller.toggleOrientation();
      expect(controller.state.isLandscape, isFalse);

      controller.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 6: ChatV2VideoController toggleMute
    // -------------------------------------------------------------------------
    test('TC-06: ChatV2VideoController toggleMute safely handles uninitialized controller', () {
      const args = ChatV2VideoPlayerArgs(
        videoUrl: 'https://vuahethong.net/video.mp4',
        title: 'demo.mp4',
      );
      final controller = ChatV2VideoController(args);

      // Khi chưa initialized, toggleMute không ném lỗi
      controller.toggleMute();
      expect(controller.state.isMuted, isFalse);

      controller.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 7: ChatV2VideoController seekTo
    // -------------------------------------------------------------------------
    test('TC-07: ChatV2VideoController seekTo safely handles uninitialized controller', () {
      const args = ChatV2VideoPlayerArgs(
        videoUrl: 'https://vuahethong.net/video.mp4',
        title: 'demo.mp4',
      );
      final controller = ChatV2VideoController(args);

      controller.seekTo(const Duration(seconds: 10));
      expect(controller.state.position, Duration.zero);

      controller.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 8: ChatV2VideoController saveVideo throws on empty bytes
    // -------------------------------------------------------------------------
    test('TC-08: ChatV2VideoController saveVideo fails gracefully when data is empty', () async {
      const args = ChatV2VideoPlayerArgs(
        videoUrl: '',
        title: 'empty.mp4',
        bytes: null,
      );
      final controller = ChatV2VideoController(args);

      expect(
        () => controller.saveVideo(),
        throwsA(isA<Exception>()),
      );

      controller.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 9: ChatV2VideoPlayerScreen renders with clean Riverpod integration
    // -------------------------------------------------------------------------
    testWidgets('TC-09: ChatV2VideoPlayerScreen renders top bar, title and actions', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          body: const ChatV2VideoPlayerScreen(
            videoUrl: 'https://vuahethong.net/web/content/500',
            title: 'huong_dan.mp4',
          ),
        ),
      );

      // Tiêu đề video hiển thị trên Top Bar
      expect(find.text('huong_dan.mp4'), findsOneWidget);

      // Nút đóng (arrowLeft)
      expect(find.byTooltip('Đóng'), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);

      // Nút Lưu video (download)
      expect(find.byTooltip('Lưu vào máy'), findsOneWidget);
      expect(find.byIcon(LucideIcons.download), findsOneWidget);

      // Lúc mới mở màn hình, hiển thị loading indicator
      expect(find.text('Đang tải video...'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Test 10: ChatV2VideoPlayerScreen handles ProviderScope override seamlessly
    // -------------------------------------------------------------------------
    testWidgets('TC-10: ChatV2VideoPlayerScreen works under existing ProviderScope', (tester) async {
      const args = ChatV2VideoPlayerArgs(
        videoUrl: 'https://vuahethong.net/web/content/700',
        title: 'intro.mp4',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: _buildTestApp(
            body: ChatV2VideoPlayerScreen(
              videoUrl: args.videoUrl,
              title: args.title,
            ),
          ),
        ),
      );

      expect(find.text('intro.mp4'), findsOneWidget);
      expect(find.byTooltip('Lưu vào máy'), findsOneWidget);
    });
  });
}

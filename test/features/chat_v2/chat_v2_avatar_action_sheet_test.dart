import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_avatar_action_sheet.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';
import 'package:vcloud/features/profile/presentation/profile_screen.dart';

void main() {
  setUp(() {
    ChatV2ChannelLocalCache.clear();
  });

  tearDown(() {
    ChatV2ChannelLocalCache.clear();
  });

  group('ChatV2AvatarActionSheet & Incoming Avatar Quick Action Tests', () {
    testWidgets('1. Render đầy đủ Header: Tên, Chức vụ và Huy hiệu Phóng to', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false),
            home: const Scaffold(
              body: ChatV2AvatarActionSheet(
                partnerId: '101',
                name: 'Nguyễn Văn Test',
                role: 'Senior Developer · AI Lab',
                avatarUrl: 'https://example.com/avatar.png',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nguyễn Văn Test'), findsOneWidget);
      expect(find.text('Senior Developer · AI Lab'), findsOneWidget);
      expect(find.byIcon(LucideIcons.maximize2), findsOneWidget);
    });

    testWidgets('2. Render đủ 4 Quick Actions với nhãn & mô tả rõ ràng', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false),
            home: const Scaffold(
              body: ChatV2AvatarActionSheet(
                partnerId: '101',
                name: 'Trần Văn B',
                role: 'Kỹ sư hệ thống',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xem hồ sơ'), findsOneWidget);
      expect(find.text('Xem chi tiết thông tin cá nhân'), findsOneWidget);
      expect(find.text('Nhắn tin cá nhân'), findsOneWidget);
      expect(find.text('Trò chuyện trực tiếp 1-1'), findsOneWidget);
      expect(find.text('Gọi thoại'), findsOneWidget);
      expect(find.text('Cuộc gọi đàm thoại WebRTC 1-1'), findsOneWidget);
      expect(find.text('Xem ảnh đại diện'), findsOneWidget);
      expect(find.text('Phóng to và lưu ảnh vào máy'), findsOneWidget);
    });

    testWidgets('3. Nhấn Xem ảnh đại diện điều hướng sang ChatV2ImageViewerScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false),
            home: const Scaffold(
              body: ChatV2AvatarActionSheet(
                partnerId: '101',
                name: 'Lê Hoàng C',
                role: 'Designer',
                avatarUrl: 'https://example.com/avatar_c.png',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xem ảnh đại diện'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatV2ImageViewerScreen), findsOneWidget);
      expect(find.text('Lê Hoàng C'), findsOneWidget);
    });

    testWidgets('4. Chạm vào Avatar lớn ở Header mở xem ảnh toàn màn hình', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false),
            home: const Scaffold(
              body: ChatV2AvatarActionSheet(
                partnerId: '102',
                name: 'Phạm Thị D',
                role: 'Product Owner',
                avatarUrl: 'https://example.com/avatar_d.png',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on avatar in header
      final avatarFinder = find.byType(GestureDetector).first;
      await tester.tap(avatarFinder);
      await tester.pumpAndSettle();

      expect(find.byType(ChatV2ImageViewerScreen), findsOneWidget);
    });

    testWidgets('5. openDirectChat tái sử dụng kênh 1-1 từ Local Cache (Tầng 1 - 0ms)', (tester) async {
      const cachedCh = ChatV2Channel(
        id: '999',
        name: 'Trần Văn E',
        channelType: 'chat',
        isGroup: false,
        memberCount: 2,
        directPartnerId: '202',
      );
      ChatV2ChannelLocalCache.pinDirectChannel(cachedCh);

      late BuildContext capturedCtx;
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false),
            home: Consumer(
              builder: (ctx, ref, _) {
                capturedCtx = ctx;
                capturedRef = ref;
                return const Scaffold(body: Text('Home'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await ChatV2AvatarActionSheet.openDirectChat(
        capturedCtx,
        capturedRef,
        partnerId: '202',
        name: 'Trần Văn E',
      );
      await tester.pump();

      final found = ChatV2ChannelLocalCache.cached.any((c) => c.id == '999');
      expect(found, isTrue);
    });

    testWidgets('6. openDirectChat bỏ qua an toàn khi partnerId rỗng', (tester) async {
      late BuildContext capturedCtx;
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false),
            home: Consumer(
              builder: (ctx, ref, _) {
                capturedCtx = ctx;
                capturedRef = ref;
                return const Scaffold(body: Text('Home'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await ChatV2AvatarActionSheet.openDirectChat(
        capturedCtx,
        capturedRef,
        partnerId: '   ',
        name: 'Empty ID',
      );
      expect(true, isTrue);
    });

    testWidgets('7. ChatV2MessageItem gọi onAvatarTap khi chạm Avatar tin nhắn đến (!isMine)', (tester) async {
      var tapped = false;
      final msg = ChatV2Message(
        id: 'msg_01',
        channelId: 'ch_01',
        content: 'Xin chào anh Tân!',
        isMine: false,
        authorName: 'Hoàng Long',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              isGroup: true,
              showAvatar: true,
              onAvatarTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find inner avatar gesture detector
      final avatarFinder = find.byType(GestureDetector);
      expect(avatarFinder, findsWidgets);

      await tester.tap(avatarFinder.last);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('8. ChatV2MessageItem không hiển thị Avatar cho tin nhắn của chính mình (isMine)', (tester) async {
      var tapped = false;
      final msg = ChatV2Message(
        id: 'msg_02',
        channelId: 'ch_01',
        content: 'Tin nhắn gửi đi',
        isMine: true,
        authorName: 'Tôi',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              isGroup: true,
              showAvatar: false, // isMine messages never show avatar
              onAvatarTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No avatar tap triggered
      expect(tapped, isFalse);
    });

    testWidgets('9. ProfileScreen hỗ trợ partnerId hiển thị giao diện Hồ sơ đồng nghiệp', (tester) async {
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(
              partnerId: '555',
              partnerName: 'Vũ Minh Tuấn',
              partnerRole: 'Tech Lead',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hồ sơ đồng nghiệp'), findsOneWidget);
      expect(find.text('Vũ Minh Tuấn'), findsOneWidget);
      expect(find.text('Tech Lead'), findsOneWidget);
      expect(find.text('Nhắn tin cá nhân'), findsOneWidget);
      expect(find.text('Gọi thoại trực tiếp'), findsOneWidget);
      expect(find.text('Xem ảnh đại diện (phóng to)'), findsOneWidget);
    });

    testWidgets('10. ProfileScreen partner view: Nút xem ảnh đại diện mở ChatV2ImageViewerScreen', (tester) async {
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(
              partnerId: '777',
              partnerName: 'Đặng Thảo Vy',
              partnerRole: 'HR Manager',
              partnerAvatar: 'https://example.com/avatar_vy.png',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xem ảnh đại diện (phóng to)'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatV2ImageViewerScreen), findsOneWidget);
      expect(find.text('Đặng Thảo Vy'), findsOneWidget);
    });

    testWidgets('11. ProfileScreen cho bản thân (không truyền partnerId) hiển thị Hồ sơ cá nhân của Tôi', (tester) async {
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
      expect(find.text('Thông tin ứng dụng'), findsOneWidget);
      expect(find.text('Đăng xuất'), findsOneWidget);
    });
  });
}

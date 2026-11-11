import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_inbox_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/domain/models/chat_v2_inbox_item.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_list_screen.dart';

class FakeInboxController extends ChatV2InboxController {
  final ChatV2InboxState? initial;
  FakeInboxController([this.initial]);

  @override
  ChatV2InboxState build() {
    return initial ?? const ChatV2InboxState();
  }

  @override
  void switchTab(ChatV2InboxTabType tab) {
    state = state.copyWith(activeTab: tab);
  }
}

class FakeChannelsNotifier extends ChatV2ChannelsNotifier {
  final List<ChatV2Channel> initialChannels;
  FakeChannelsNotifier(this.initialChannels);

  @override
  Future<List<ChatV2Channel>> build() async {
    return initialChannels;
  }
}

class FakeAuthController extends AuthController {
  final AuthUser? user;
  FakeAuthController(this.user);

  @override
  Future<AuthUser?> build() async {
    return user;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockUser = AuthUser(
    id: '1',
    email: 'admin@vcloud.vn',
    userMetadata: {
      'name': 'Sếp Tân',
      'partner_id': 3,
      'has_v_mobile': true,
      'db': 'vcloud_test_v19',
    },
  );

  final sampleChannels = [
    ChatV2Channel(
      id: '101',
      name: 'Nguyễn Văn A',
      channelType: 'chat',
      directPartnerName: 'Nguyễn Văn A',
      unreadCount: 2,
      lastMessage: 'Chào Sếp',
      lastMessageDate: DateTime.now(),
    ),
    ChatV2Channel(
      id: '102',
      name: 'Kênh Chung Vcloud',
      channelType: 'channel',
      isGroup: true,
      lastMessage: 'Update tiến độ',
      lastMessageDate: DateTime.now(),
    ),
  ];

  final sampleInboxItem = ChatV2InboxItem(
    id: 1,
    subject: 'Thông báo Odoo Task #101',
    recordName: 'Task #101',
    model: 'project.task',
    resId: 101,
    body: 'Vui lòng kiểm tra task',
    date: DateTime.now(),
    authorName: 'Hệ thống Odoo',
  );

  Widget createWidgetUnderTest({
    ChatV2InboxState? customInboxState,
    int unreadCount = 4,
    FakeInboxController? controller,
  }) {
    final inboxController = controller ?? FakeInboxController(
      customInboxState ??
          ChatV2InboxState(
            inboxItems: [sampleInboxItem],
            inboxTotal: 3,
            starredItems: [sampleInboxItem],
            historyItems: [sampleInboxItem],
            activeTab: ChatV2InboxTabType.inbox,
            isLoading: false,
          ),
    );

    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (context, state) => const ChatV2ListScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => FakeAuthController(mockUser)),
        chatV2ChannelsProvider.overrideWith(() => FakeChannelsNotifier(sampleChannels)),
        chatV2TotalUnreadProvider.overrideWithValue(unreadCount),
        chatV2SyncStatusProvider.overrideWith((ref) => ChatV2SyncStatus.synced),
        chatV2InboxControllerProvider.overrideWith(() => inboxController),
      ],
      child: MaterialApp.router(
        theme: ThemeData(
          splashFactory: NoSplash.splashFactory,
        ),
        routerConfig: router,
      ),
    );
  }

  group('Kiểm thử 10 case độc lập: Tab Switcher 2 Tầng (Hội thoại vs Hộp thư Odoo)', () {
    testWidgets('1. Tầng 1: Hiển thị đầy đủ 2 nút chuyển đổi chính "Hội thoại" và "Hộp thư Odoo"', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Hội thoại'), findsOneWidget);
      expect(find.text('Hộp thư Odoo'), findsOneWidget);
    });

    testWidgets('2. Tầng 1: "Hội thoại" hiển thị badge đếm tin chưa đọc chính xác (4 tin)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest(unreadCount: 4));
      await tester.pumpAndSettle();

      expect(find.text('4'), findsWidgets);
    });

    testWidgets('3. Tầng 1: "Hộp thư Odoo" hiển thị badge tin cần xử lý (3 tin)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('3'), findsWidgets);
    });

    testWidgets('4. Tầng 2: Khi ở tab Hội thoại, hiển thị các chip lọc kênh (Tất cả, Chưa đọc, Trực tiếp, Kênh)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Chưa đọc'), findsOneWidget);
      expect(find.text('Trực tiếp'), findsOneWidget);
      expect(find.text('Kênh'), findsOneWidget);
    });

    testWidgets('5. Tầng 2: Khi ở tab Hội thoại, đã loại bỏ sạch các chip cũ ("Hộp thư đến", "Đã gắn sao", "Lịch sử")', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Các nhãn sub-tab mailbox không được xuất hiện ở chế độ Hội thoại
      expect(find.text('Hộp thư đến'), findsNothing);
      expect(find.text('Cần xử lý'), findsNothing);
      expect(find.text('Đã gắn sao'), findsNothing);
      expect(find.text('Lịch sử'), findsNothing);
    });

    testWidgets('6. Tầng 1 -> Tầng 2: Bấm chọn "Hộp thư Odoo" hiển thị ngay 3 phân đoạn: "Cần xử lý", "Đã gắn sao", "Lịch sử"', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Nhấn chuyển sang Hộp thư Odoo
      await tester.tap(find.text('Hộp thư Odoo'));
      await tester.pumpAndSettle();

      // Lúc này Tầng 2 hiển thị 3 phân đoạn
      expect(find.text('Cần xử lý'), findsOneWidget);
      expect(find.text('Đã gắn sao'), findsOneWidget);
      expect(find.text('Lịch sử'), findsOneWidget);

      // Các chip hội thoại phải bị ẩn
      expect(find.text('Tất cả'), findsNothing);
      expect(find.text('Trực tiếp'), findsNothing);
    });

    testWidgets('7. Tầng 2 (Mailbox): Nhấn sub-segment "Đã gắn sao" kích hoạt chuyển tab starred', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = FakeInboxController(
        ChatV2InboxState(
          inboxItems: [sampleInboxItem],
          inboxTotal: 1,
          starredItems: [sampleInboxItem],
          historyItems: [],
          activeTab: ChatV2InboxTabType.inbox,
          isLoading: false,
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hộp thư Odoo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đã gắn sao'));
      await tester.pumpAndSettle();

      expect(controller.state.activeTab, equals(ChatV2InboxTabType.starred));
    });

    testWidgets('8. Tầng 2 (Mailbox): Nhấn sub-segment "Lịch sử" kích hoạt chuyển tab history', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = FakeInboxController(
        ChatV2InboxState(
          inboxItems: [sampleInboxItem],
          inboxTotal: 1,
          starredItems: [],
          historyItems: [sampleInboxItem],
          activeTab: ChatV2InboxTabType.inbox,
          isLoading: false,
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hộp thư Odoo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();

      expect(controller.state.activeTab, equals(ChatV2InboxTabType.history));
    });

    testWidgets('9. Tầng 2 (Mailbox): Nhấn sub-segment "Cần xử lý" kích hoạt chuyển tab inbox', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = FakeInboxController(
        ChatV2InboxState(
          inboxItems: [sampleInboxItem],
          inboxTotal: 1,
          starredItems: [],
          historyItems: [],
          activeTab: ChatV2InboxTabType.starred,
          isLoading: false,
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hộp thư Odoo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cần xử lý'));
      await tester.pumpAndSettle();

      expect(controller.state.activeTab, equals(ChatV2InboxTabType.inbox));
    });

    testWidgets('10. Tầng 1: Bấm quay lại "Hội thoại" khôi phục ngay thanh chip lọc kênh và ẩn 3 phân đoạn Mailbox', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Sang Hộp thư Odoo
      await tester.tap(find.text('Hộp thư Odoo'));
      await tester.pumpAndSettle();
      expect(find.text('Cần xử lý'), findsOneWidget);

      // Quay lại Hội thoại
      await tester.tap(find.text('Hội thoại'));
      await tester.pumpAndSettle();

      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Trực tiếp'), findsOneWidget);
      expect(find.text('Cần xử lý'), findsNothing);
      expect(find.text('Đã gắn sao'), findsNothing);
    });
  });
}

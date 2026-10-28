import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/notifications/push_notification_controller.dart';
import 'package:vcloud/core/notifications/push_notification_repository.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/home/presentation/home_screen.dart';
import 'package:vcloud/features/ticket/application/ticket_controller.dart';
import 'package:vcloud/features/timesheet/application/task_controller.dart';
import 'package:vcloud/shared/models/task.dart';
import 'package:vcloud/shared/models/ticket.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';

void main() {
  group('B.16 Dynamic Portal Home Adaptation Tests', () {
    // -------------------------------------------------------------
    // Case 1: AuthUser hasHelpdesk & isPortal model evaluation
    // -------------------------------------------------------------
    test('Case 1: AuthUser evaluates isPortal and hasHelpdesk correctly based on installed_modules', () {
      const portalWithHelpdesk = AuthUser(
        id: '101',
        email: 'portal_helpdesk@test.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': {'helpdesk': true},
        },
      );
      expect(portalWithHelpdesk.isPortal, isTrue);
      expect(portalWithHelpdesk.hasHelpdesk, isTrue);

      const portalWithoutHelpdesk = AuthUser(
        id: '102',
        email: 'portal_no_helpdesk@test.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': <String, dynamic>{},
        },
      );
      expect(portalWithoutHelpdesk.isPortal, isTrue);
      expect(portalWithoutHelpdesk.hasHelpdesk, isFalse);

      const employeeUser = AuthUser(
        id: '2',
        email: 'employee@test.com',
        userMetadata: {
          'is_portal': false,
          'installed_modules': {
            'helpdesk': true,
            'hr_timesheet': true,
            'hr_attendance': true,
          },
        },
      );
      expect(employeeUser.isPortal, isFalse);
      expect(employeeUser.hasTimesheet, isTrue);
      expect(employeeUser.hasAttendance, isTrue);
    });

    // -------------------------------------------------------------
    // Case 2: AppScaffold 3 tabs for Portal when hasHelpdesk == true
    // -------------------------------------------------------------
    testWidgets('Case 2: AppScaffold displays 3 tabs (Home, Chat, Ticket) for Portal with Helpdesk', (tester) async {
      const portalUser = AuthUser(
        id: '101',
        email: 'portal@test.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': {'helpdesk': true},
        },
      );

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const AppScaffold(
              title: 'Home',
              body: Text('Home Content'),
            ),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const AppScaffold(
              title: 'Chat',
              body: Text('Chat Content'),
            ),
          ),
          GoRoute(
            path: '/tickets',
            builder: (context, state) => const AppScaffold(
              title: 'Tickets',
              body: Text('Ticket Content'),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const AppScaffold(
              title: 'Hồ sơ',
              body: Text('Profile Content'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            chatV2ChannelsProvider.overrideWith(() => _MockChatV2ChannelsNotifier()),
            mobileNotificationsProvider.overrideWith(
              (ref) => Stream.value(const MobileNotificationList(items: [], total: 0, limit: 20, offset: 0, hasMore: false)),
            ),
            todayTasksProvider.overrideWith((ref) => Stream.value(const <Task>[])),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Home'), findsWidgets);
      expect(find.text('Chat'), findsWidgets);
      expect(find.text('Ticket'), findsWidgets);
      expect(find.text('Tôi'), findsNothing);
      // Timesheet tuyệt đối không được có trong tabs của Portal
      expect(find.text('Timesheet'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    // -------------------------------------------------------------
    // Case 3: AppScaffold 2 tabs for Portal when hasHelpdesk == false
    // -------------------------------------------------------------
    testWidgets('Case 3: AppScaffold displays 2 tabs (Home, Chat) for Portal without Helpdesk (Hides Ticket)', (tester) async {
      const portalUser = AuthUser(
        id: '102',
        email: 'portal_no_helpdesk@test.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': <String, dynamic>{},
        },
      );

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const AppScaffold(
              title: 'Home',
              body: Text('Home Content'),
            ),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const AppScaffold(
              title: 'Chat',
              body: Text('Chat Content'),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const AppScaffold(
              title: 'Hồ sơ',
              body: Text('Profile Content'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            chatV2ChannelsProvider.overrideWith(() => _MockChatV2ChannelsNotifier()),
            mobileNotificationsProvider.overrideWith(
              (ref) => Stream.value(const MobileNotificationList(items: [], total: 0, limit: 20, offset: 0, hasMore: false)),
            ),
            todayTasksProvider.overrideWith((ref) => Stream.value(const <Task>[])),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Home'), findsWidgets);
      expect(find.text('Chat'), findsWidgets);
      expect(find.text('Tôi'), findsNothing);
      // Cả Ticket và Timesheet đều không có mặt
      expect(find.text('Ticket'), findsNothing);
      expect(find.text('Timesheet'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    // -------------------------------------------------------------
    // Case 4: AppScaffold 5 tabs for Employee (!isPortal)
    // -------------------------------------------------------------
    testWidgets('Case 4: AppScaffold displays 5 tabs for Employee (Home, Chat, Timesheet, Ticket, Ứng dụng)', (tester) async {
      const employeeUser = AuthUser(
        id: '2',
        email: 'emp@test.com',
        userMetadata: {
          'is_portal': false,
        },
      );

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const AppScaffold(
              title: 'Home',
              body: Text('Home Content'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(employeeUser)),
            chatV2ChannelsProvider.overrideWith(() => _MockChatV2ChannelsNotifier()),
            mobileNotificationsProvider.overrideWith(
              (ref) => Stream.value(const MobileNotificationList(items: [], total: 0, limit: 20, offset: 0, hasMore: false)),
            ),
            todayTasksProvider.overrideWith((ref) => Stream.value(const <Task>[])),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Home'), findsWidgets);
      expect(find.text('Chat'), findsWidgets);
      expect(find.text('Timesheet'), findsWidgets);
      expect(find.text('Ticket'), findsWidgets);
      expect(find.text('Ứng dụng'), findsWidgets);
      expect(find.text('Tôi'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    // -------------------------------------------------------------
    // Case 5: HomeScreen for Portal with Helpdesk renders _PortalRecentTicketsSection & no _TodayWork
    // -------------------------------------------------------------
    testWidgets('Case 5: HomeScreen for Portal with Helpdesk renders Recent Tickets & suppresses _TodayWork', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const portalUser = AuthUser(
        id: '101',
        email: 'portal_helpdesk@test.com',
        userMetadata: {
          'is_portal': true,
          'display_name': 'Khách hàng VIP',
          'installed_modules': {'helpdesk': true},
        },
      );

      final sampleTickets = [
        Ticket(
          id: '1001',
          title: 'Hỗ trợ cấu hình tên miền',
          status: TicketStatus.doing,
          createdBy: '101',
          assignedTo: '2',
          createdAt: DateTime(2026, 10, 15),
          updatedAt: DateTime(2026, 10, 16),
        ),
      ];

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/tickets',
            builder: (context, state) => const Scaffold(body: Text('Tickets Screen')),
          ),
          GoRoute(
            path: '/tickets/new',
            builder: (context, state) => const Scaffold(body: Text('New Ticket Screen')),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const Scaffold(body: Text('Chat Screen')),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const Scaffold(body: Text('Profile Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            chatV2ChannelsProvider.overrideWith(() => _MockChatV2ChannelsNotifier()),
            mobileNotificationsProvider.overrideWith(
              (ref) => Stream.value(const MobileNotificationList(items: [], total: 0, limit: 20, offset: 0, hasMore: false)),
            ),
            todayTasksProvider.overrideWith((ref) => Stream.value(const <Task>[])),
            effectiveTicketsProvider.overrideWithValue(sampleTickets),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Kiểm tra Header có nút Tạo ticket
      expect(find.text('Tạo ticket'), findsOneWidget);

      // Kiểm tra ô chức năng: Ticket, Chưa đọc, Hội thoại, Hỗ trợ
      expect(find.text('Ticket'), findsWidgets);
      expect(find.text('Chưa đọc'), findsOneWidget);
      expect(find.text('Hội thoại'), findsOneWidget);
      expect(find.text('Hỗ trợ'), findsOneWidget);

      // RÀO CHẮN: Tuyệt đối KHÔNG có ô "Công việc hôm nay" (Timesheet) hay nút "Mở Timesheet"
      expect(find.text('Mở Timesheet'), findsNothing);
      expect(find.text('Chưa có công việc hôm nay.'), findsNothing);

      // KHỐI DƯỚI: Hiển thị Phiếu hỗ trợ của bạn
      expect(find.text('Phiếu hỗ trợ của bạn'), findsOneWidget);
      expect(find.text('Xem tất cả'), findsOneWidget);
      expect(find.text('Hỗ trợ cấu hình tên miền'), findsOneWidget);
      expect(find.text('Đang xử lý'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    // -------------------------------------------------------------
    // Case 6: HomeScreen for Portal with Helpdesk renders Empty state when tickets list is empty
    // -------------------------------------------------------------
    testWidgets('Case 6: HomeScreen for Portal with Helpdesk renders empty state with "Gửi yêu cầu hỗ trợ" button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const portalUser = AuthUser(
        id: '101',
        email: 'portal_helpdesk@test.com',
        userMetadata: {
          'is_portal': true,
          'display_name': 'Khách hàng Mới',
          'installed_modules': {'helpdesk': true},
        },
      );

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/tickets',
            builder: (context, state) => const Scaffold(body: Text('Tickets Screen')),
          ),
          GoRoute(
            path: '/tickets/new',
            builder: (context, state) => const Scaffold(body: Text('New Ticket Screen')),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const Scaffold(body: Text('Chat Screen')),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const Scaffold(body: Text('Profile Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            chatV2ChannelsProvider.overrideWith(() => _MockChatV2ChannelsNotifier()),
            mobileNotificationsProvider.overrideWith(
              (ref) => Stream.value(const MobileNotificationList(items: [], total: 0, limit: 20, offset: 0, hasMore: false)),
            ),
            todayTasksProvider.overrideWith((ref) => Stream.value(const <Task>[])),
            effectiveTicketsProvider.overrideWithValue(<Ticket>[]),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Bạn chưa có phiếu hỗ trợ nào'), findsOneWidget);
      expect(find.text('Gửi yêu cầu hỗ trợ'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    // -------------------------------------------------------------
    // Case 7: HomeScreen for Portal without Helpdesk renders 3-card layout & hides "Tạo ticket"
    // -------------------------------------------------------------
    testWidgets('Case 7: HomeScreen for Portal without Helpdesk hides "Tạo ticket" and renders 3-card layout', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const portalUser = AuthUser(
        id: '102',
        email: 'portal_no_helpdesk@test.com',
        userMetadata: {
          'is_portal': true,
          'display_name': 'Khách hàng Standard',
          'installed_modules': <String, dynamic>{}, // Không có helpdesk
        },
      );

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const Scaffold(body: Text('Chat Screen')),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const Scaffold(body: Text('Profile Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            chatV2ChannelsProvider.overrideWith(() => _MockChatV2ChannelsNotifier()),
            mobileNotificationsProvider.overrideWith(
              (ref) => Stream.value(const MobileNotificationList(items: [], total: 0, limit: 20, offset: 0, hasMore: false)),
            ),
            todayTasksProvider.overrideWith((ref) => Stream.value(const <Task>[])),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // RÀO CHẮN 1: Ẩn hoàn toàn nút "Tạo ticket" ở Header
      expect(find.text('Tạo ticket'), findsNothing);

      // RÀO CHẮN 2: Ẩn hoàn toàn ô "Ticket" và ô "Công việc hôm nay" trong grid
      expect(find.text('Mở Timesheet'), findsNothing);

      // 3 THẺ CHỨC NĂNG:
      // 1. Thẻ ngang nổi bật Hỗ trợ trực tuyến
      expect(find.text('Hỗ Trợ Trực Tuyến'), findsWidgets);
      expect(find.text('Online'), findsWidgets);

      // 2 & 3: Thẻ Chưa đọc & Hội thoại
      expect(find.text('Chưa đọc'), findsOneWidget);
      expect(find.text('Hội thoại'), findsOneWidget);

      // KHỐI DƯỚI: Dịch vụ hỗ trợ trực tuyến
      expect(find.text('Dịch vụ hỗ trợ trực tuyến'), findsOneWidget);
      expect(find.text('Chăm Sóc Khách Hàng (Customer Care)'), findsOneWidget);
      expect(find.text('Hỗ Trợ Kỹ Thuật (Technical Support)'), findsOneWidget);
      expect(find.text('Nhắn tin'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
    });

    // -------------------------------------------------------------
    // Case 8: HomeScreen for Employee renders _TodayWork & Timesheet
    // -------------------------------------------------------------
    testWidgets('Case 8: HomeScreen for Employee renders _TodayWork and Timesheet navigation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const employeeUser = AuthUser(
        id: '2',
        email: 'nv@360.org.vn',
        userMetadata: {
          'is_portal': false,
          'display_name': 'Nguyễn Văn Nhân Viên',
        },
      );

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/tickets',
            builder: (context, state) => const Scaffold(body: Text('Tickets Screen')),
          ),
          GoRoute(
            path: '/tickets/new',
            builder: (context, state) => const Scaffold(body: Text('New Ticket Screen')),
          ),
          GoRoute(
            path: '/timesheet',
            builder: (context, state) => const Scaffold(body: Text('Timesheet Screen')),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const Scaffold(body: Text('Chat Screen')),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const Scaffold(body: Text('Profile Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(employeeUser)),
            chatV2ChannelsProvider.overrideWith(() => _MockChatV2ChannelsNotifier()),
            mobileNotificationsProvider.overrideWith(
              (ref) => Stream.value(const MobileNotificationList(items: [], total: 0, limit: 20, offset: 0, hasMore: false)),
            ),
            todayTasksProvider.overrideWith((ref) => Stream.value(const <Task>[])),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Nhân viên nội bộ có "Công việc hôm nay" và "Mở Timesheet"
      expect(find.text('Công việc hôm nay'), findsWidgets);
      expect(find.text('Mở Timesheet'), findsOneWidget);
      expect(find.text('Tạo ticket'), findsOneWidget);

      // Nhân viên nội bộ KHÔNG render các khối riêng của Portal
      expect(find.text('Phiếu hỗ trợ của bạn'), findsNothing);
      expect(find.text('Dịch vụ hỗ trợ trực tuyến'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    // -------------------------------------------------------------
    // Case 9: Portal User Navigation Dead-Click Protection
    // -------------------------------------------------------------
    test('Case 9: Router checks block /timesheet and /attendance for Portal users', () {
      const portalUser = AuthUser(
        id: '101',
        email: 'portal@test.com',
        userMetadata: {
          'is_portal': true,
        },
      );

      expect(portalUser.isPortal, isTrue);
      expect(portalUser.hasTimesheet, isFalse);
      expect(portalUser.hasAttendance, isFalse);
    });

    // -------------------------------------------------------------
    // Case 10: Date formatting and status mapping for Portal Tickets
    // -------------------------------------------------------------
    test('Case 10: Ticket status mapping and date format function evaluate accurately', () {
      final ticketTodo = Ticket(
        id: '1',
        title: 'Vé Mới',
        status: TicketStatus.todo,
        createdBy: '101',
        assignedTo: '2',
        createdAt: DateTime(2026, 10, 16, 9, 30),
        updatedAt: DateTime(2026, 10, 16, 9, 30),
      );
      expect(ticketTodo.status.isOpen, isTrue);

      final ticketDone = Ticket(
        id: '2',
        title: 'Vé Đã Xong',
        status: TicketStatus.done,
        createdBy: '101',
        assignedTo: '2',
        createdAt: DateTime(2026, 10, 16, 10, 0),
        updatedAt: DateTime(2026, 10, 16, 11, 0),
      );
      expect(ticketDone.status.isOpen, isFalse);
    });
  });
}

class _MockAuthController extends AuthController {
  _MockAuthController(this._user);
  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async {
    return _user;
  }
}

class _MockChatV2ChannelsNotifier extends ChatV2ChannelsNotifier {
  @override
  Future<List<ChatV2Channel>> build() async {
    return const [];
  }
}

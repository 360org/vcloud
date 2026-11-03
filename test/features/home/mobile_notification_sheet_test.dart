import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/notifications/push_notification_controller.dart';
import 'package:vcloud/core/notifications/push_notification_repository.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/home/presentation/widgets/mobile_notification_sheet.dart';

class _MockAuthController extends AuthController {
  _MockAuthController(this._user);
  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}

class _FakeDismissedNotificationNotifier extends DismissedNotificationNotifier {
  _FakeDismissedNotificationNotifier([Set<String> initial = const {}]) {
    state = initial;
  }

  @override
  Future<void> dismiss(String key) async {
    state = {...state, key};
  }

  @override
  Future<void> dismissAll(Iterable<String> keys) async {
    state = {...state, ...keys};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testNotifList = MobileNotificationList(
    items: [
      MobileNotificationItem(
        id: 1,
        eventType: 'ticket',
        title: 'Phiếu #123 được cập nhật',
        body: 'Kỹ thuật viên đã phản hồi yêu cầu',
        data: const {'ticket_id': 123},
        status: 'delivered',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      MobileNotificationItem(
        id: 2,
        eventType: 'livechat',
        title: 'Tin nhắn CSKH mới',
        body: 'Tư vấn viên: Xin chào quý khách',
        data: const {'channel_id': 456},
        status: 'delivered',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      MobileNotificationItem(
        id: 3,
        eventType: 'attendance',
        title: 'Nhắc nhở chấm công',
        body: 'Bạn chưa check-out ca làm việc hôm nay',
        data: const {},
        status: 'delivered',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      MobileNotificationItem(
        id: 4,
        eventType: 'task',
        title: 'Nhiệm vụ mới',
        body: 'Bạn được giao công việc: Kiểm thử API',
        data: const {'task_id': 789},
        status: 'delivered',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      MobileNotificationItem(
        id: 5,
        eventType: 'system',
        title: 'Bảo trì hệ thống',
        body: 'Hệ thống sẽ bảo trì vào lúc 23:00 tối nay',
        data: const {},
        status: 'delivered',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ],
    total: 5,
    limit: 20,
    offset: 0,
    hasMore: false,
  );

  const employeeUser = AuthUser(
    id: '1',
    email: 'staff@360.org.vn',
    userMetadata: {
      'is_portal': false,
      'role': 'employee',
      'display_name': 'Nguyễn Văn Staff',
    },
  );

  const portalUser = AuthUser(
    id: '2',
    email: 'khachhang@client.vn',
    userMetadata: {
      'is_portal': true,
      'role': 'portal',
      'display_name': 'Khách Hàng Portal',
    },
  );

  group('MobileNotificationSheet Test Suite (BUG-030)', () {
    // Case 1: Sheet hiển thị danh sách MobileNotificationItem từ provider
    testWidgets('Case 1: Sheet hiển thị đầy đủ tiêu đề và nội dung thông báo', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(employeeUser)),
            mobileNotificationsProvider.overrideWith((ref) => Stream.value(testNotifList)),
            dismissedNotificationIdsProvider.overrideWith((ref) => _FakeDismissedNotificationNotifier()),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const Scaffold(body: MobileNotificationSheet()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.text('Phiếu #123 được cập nhật'), findsOneWidget);
      expect(find.text('Tin nhắn CSKH mới'), findsOneWidget);
    });

    // Case 2: Portal User (isPortal: true) lọc chỉ nhận ticket, livechat, system
    testWidgets('Case 2: Portal User chỉ nhìn thấy ticket, livechat, system (ẩn attendance, task)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            mobileNotificationsProvider.overrideWith((ref) => Stream.value(testNotifList)),
            dismissedNotificationIdsProvider.overrideWith((ref) => _FakeDismissedNotificationNotifier()),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const Scaffold(body: MobileNotificationSheet()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Được phép thấy: ticket, livechat, system
      expect(find.text('Phiếu #123 được cập nhật'), findsOneWidget);
      expect(find.text('Tin nhắn CSKH mới'), findsOneWidget);
      expect(find.text('Bảo trì hệ thống'), findsOneWidget);

      // Tuyệt đối KHÔNG được thấy: attendance, task
      expect(find.text('Nhắc nhở chấm công'), findsNothing);
      expect(find.text('Nhiệm vụ mới'), findsNothing);
    });

    // Case 3: Nhân viên nội bộ (isPortal: false) nhận đầy đủ thông báo
    testWidgets('Case 3: Nhân viên nội bộ nhận trọn vẹn 5 thông báo', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(employeeUser)),
            mobileNotificationsProvider.overrideWith((ref) => Stream.value(testNotifList)),
            dismissedNotificationIdsProvider.overrideWith((ref) => _FakeDismissedNotificationNotifier()),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const Scaffold(body: MobileNotificationSheet()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Phiếu #123 được cập nhật'), findsOneWidget);
      expect(find.text('Tin nhắn CSKH mới'), findsOneWidget);
      expect(find.text('Nhắc nhở chấm công'), findsOneWidget);
      expect(find.text('Nhiệm vụ mới'), findsOneWidget);
      expect(find.text('Bảo trì hệ thống'), findsOneWidget);
    });

    // Case 4: Dismissed ID làm item biến mất khỏi danh sách chưa đọc
    testWidgets('Case 4: Item có id trong dismissedIds được xem là đã đọc', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(employeeUser)),
            mobileNotificationsProvider.overrideWith((ref) => Stream.value(testNotifList)),
            dismissedNotificationIdsProvider.overrideWith((ref) => _FakeDismissedNotificationNotifier({'1', '2'})),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const Scaffold(body: MobileNotificationSheet()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Số đếm badge chưa đọc còn 3 (5 - 2)
      expect(find.text('3'), findsOneWidget);
    });

    // Case 5: Bấm "Đã đọc tất cả" gọi dismissAll
    testWidgets('Case 5: Bấm nút Đã đọc tất cả cập nhật dismissedIds', (tester) async {
      final fakeNotifier = _FakeDismissedNotificationNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            mobileNotificationsProvider.overrideWith((ref) => Stream.value(testNotifList)),
            dismissedNotificationIdsProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const Scaffold(body: MobileNotificationSheet()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final markAllBtn = find.text('Đã đọc tất cả');
      expect(markAllBtn, findsOneWidget);

      await tester.tap(markAllBtn);
      await tester.pump();

      // Portal có 3 unread items (1, 2, 5), tất cả được đưa vào dismissed
      expect(fakeNotifier.state.contains('1'), isTrue);
      expect(fakeNotifier.state.contains('2'), isTrue);
      expect(fakeNotifier.state.contains('5'), isTrue);
    });

    // Case 6: Hiển thị Empty state khi danh sách rỗng
    testWidgets('Case 6: Hiển thị Empty State khi không có thông báo nào', (tester) async {
      const emptyList = MobileNotificationList(
        items: [],
        total: 0,
        limit: 20,
        offset: 0,
        hasMore: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController(portalUser)),
            mobileNotificationsProvider.overrideWith((ref) => Stream.value(emptyList)),
            dismissedNotificationIdsProvider.overrideWith((ref) => _FakeDismissedNotificationNotifier()),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const Scaffold(body: MobileNotificationSheet()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Không có thông báo nào'), findsOneWidget);
      expect(find.text('Bạn chưa có thông báo về vé hỗ trợ hoặc tin nhắn.'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/activity/data/repositories/activity_repository.dart';
import 'package:vcloud/features/activity/presentation/screens/activity_center_screen.dart';
import 'package:vcloud/shared/widgets/empty_state.dart';

class _EmptyActivityApiClient implements OdooApiClient {
  int getCallCount = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool auth = true,
    Duration? timeout,
  }) async {
    getCallCount++;
    if (path == '/api/v1/mobile/activities/types') {
      return [];
    }
    // Trả về danh sách rỗng để kích hoạt EmptyState
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kiểm thử Phòng thủ Layout: EmptyState & ActivityCenterScreen Không Overflow', () {
    testWidgets('1. EmptyState an toàn tuyệt đối trong Box Constraints hẹp (200px height)', (tester) async {
      // Giả lập vùng chứa chỉ có chiều cao 200px (thấp hơn chiều cao 328px ban đầu)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: 200,
                width: 320,
                child: EmptyState(
                  icon: LucideIcons.calendarCheck,
                  title: 'Không có việc cần làm nào',
                  subtitle: 'Mọi việc cần làm theo tiêu chí này đã được xử lý xong.',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm chứng: Không có bất kỳ ngoại lệ RenderFlex overflow nào bị ném ra
      expect(tester.takeException(), isNull);
      expect(find.text('Không có việc cần làm nào'), findsOneWidget);
    });

    testWidgets('2. EmptyState an toàn trong Box Constraints siêu hẹp (150px height)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: 150,
                width: 280,
                child: EmptyState(
                  icon: LucideIcons.inbox,
                  title: 'Trống rỗng',
                  subtitle: 'Mô tả rất dài để kiểm tra độ co giãn và khả năng cuộn phòng thủ của widget.',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Trống rỗng'), findsOneWidget);
    });

    testWidgets('3. ActivityCenterScreen trên màn hình Redroid nhỏ (650x360) không bị Bottom Overflow', (tester) async {
      final mockClient = _EmptyActivityApiClient();

      // Thiết lập kích thước màn hình Redroid giả lập (chiều cao 650, chiều rộng 360)
      tester.view.physicalSize = const Size(360, 650);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/activities',
        routes: [
          GoRoute(
            path: '/activities',
            builder: (_, _) => const ActivityCenterScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityRepositoryProvider.overrideWithValue(
              ActivityRepository(mockClient),
            ),
          ],
          child: MaterialApp.router(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm chứng 1: Tuyệt đối không ném ngoại lệ RenderFlex overflowed
      expect(tester.takeException(), isNull);

      // Kiểm chứng 2: EmptyState hiển thị đầy đủ tiêu đề và phụ đề
      expect(find.text('Không có việc cần làm nào'), findsOneWidget);
      expect(
        find.text('Mọi việc cần làm theo tiêu chí này đã được xử lý xong.'),
        findsOneWidget,
      );

      // Kiểm chứng 3: Header tab vẫn hoạt động bình thường
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('🔴 Quá hạn'), findsOneWidget);
      expect(find.text('🟢 Hôm nay'), findsOneWidget);
      expect(find.text('🟡 Sắp tới'), findsOneWidget);
    });

    testWidgets('4. ActivityCenterScreen cho phép kéo vuốt làm mới (Pull-to-Refresh) khi danh sách trống', (tester) async {
      final mockClient = _EmptyActivityApiClient();

      tester.view.physicalSize = const Size(360, 650);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/activities',
        routes: [
          GoRoute(
            path: '/activities',
            builder: (_, _) => const ActivityCenterScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityRepositoryProvider.overrideWithValue(
              ActivityRepository(mockClient),
            ),
          ],
          child: MaterialApp.router(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      final initialCallCount = mockClient.getCallCount;

      // Thực hiện thao tác kéo vuốt xuống để kích hoạt RefreshIndicator
      await tester.fling(
        find.text('Không có việc cần làm nào'),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Kiểm chứng: API getActivities được gọi lại để nạp mới dữ liệu
      expect(mockClient.getCallCount, greaterThan(initialCallCount));
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Chuyển đổi giữa các tab hạn chót khi rỗng đều không bị lỗi layout', (tester) async {
      final mockClient = _EmptyActivityApiClient();

      final router = GoRouter(
        initialLocation: '/activities',
        routes: [
          GoRoute(
            path: '/activities',
            builder: (_, _) => const ActivityCenterScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityRepositoryProvider.overrideWithValue(
              ActivityRepository(mockClient),
            ),
          ],
          child: MaterialApp.router(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Chuyển sang tab 🔴 Quá hạn
      await tester.tap(find.text('🔴 Quá hạn'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Không có việc cần làm nào'), findsOneWidget);

      // Chuyển sang tab 🟢 Hôm nay
      await tester.tap(find.text('🟢 Hôm nay'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Không có việc cần làm nào'), findsOneWidget);

      // Chuyển sang tab 🟡 Sắp tới
      await tester.tap(find.text('🟡 Sắp tới'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Không có việc cần làm nào'), findsOneWidget);
    });
  });
}

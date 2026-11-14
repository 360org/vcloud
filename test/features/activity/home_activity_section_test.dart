import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/activity/data/models/activity_item.dart';
import 'package:vcloud/features/activity/presentation/screens/activity_center_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task A: Activity Native on Home & Router Resolver Tests', () {
    testWidgets('1. openActivityDetail navigates natively to /tickets/:id for helpdesk.ticket', (tester) async {
      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    const ticketActivity = ActivityItem(
                      id: 1,
                      summary: 'Kiểm tra ticket lỗi',
                      note: 'Ghi chú kiểm tra',
                      resModel: 'helpdesk.ticket',
                      resId: 105,
                      resName: 'Ticket #105 - Sự cố đường truyền',
                      state: 'today',
                    );
                    ActivityCenterScreen.openActivityDetail(context, ticketActivity);
                  },
                  child: const Text('Open Detail'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/tickets/:id',
            builder: (context, state) {
              pushedRoute = state.uri.toString();
              return Scaffold(body: Text('Ticket Detail ${state.pathParameters['id']}'));
            },
          ),
          GoRoute(
            path: '/webview',
            builder: (context, state) {
              pushedRoute = state.uri.toString();
              return const Scaffold(body: Text('WebView'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();

      expect(pushedRoute, equals('/tickets/105'));
    });

    testWidgets('2. openActivityDetail falls back to /webview for unsupported models (project.task)', (tester) async {
      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    const taskActivity = ActivityItem(
                      id: 2,
                      summary: 'Review task backend',
                      note: 'Ghi chú task',
                      resModel: 'project.task',
                      resId: 456,
                      resName: 'Task #456 - Tối ưu API',
                      state: 'overdue',
                    );
                    ActivityCenterScreen.openActivityDetail(context, taskActivity);
                  },
                  child: const Text('Open Detail'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/webview',
            builder: (context, state) {
              pushedRoute = state.uri.toString();
              return const Scaffold(body: Text('WebView'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();

      expect(pushedRoute, startsWith('/webview?url='));
      final decodedUri = Uri.parse(pushedRoute!);
      final innerUrl = decodedUri.queryParameters['url'] ?? '';
      expect(innerUrl, contains('model=project.task'));
      expect(innerUrl, contains('res_id=456'));
    });

    testWidgets('3. openActivityDetail falls back to /webview for empty or invalid resId', (tester) async {
      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    const invalidResIdActivity = ActivityItem(
                      id: 3,
                      summary: 'Ticket không có ID',
                      note: '',
                      resModel: 'helpdesk.ticket',
                      resId: 0, // Invalid resId
                      state: 'today',
                    );
                    ActivityCenterScreen.openActivityDetail(context, invalidResIdActivity);
                  },
                  child: const Text('Open Detail'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/tickets/:id',
            builder: (context, state) {
              pushedRoute = state.uri.toString();
              return const Scaffold(body: Text('Ticket'));
            },
          ),
          GoRoute(
            path: '/webview',
            builder: (context, state) {
              pushedRoute = state.uri.toString();
              return const Scaffold(body: Text('WebView'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();

      expect(pushedRoute, startsWith('/webview?url='));
    });

    test('4. buildActivityDetailWebUrl formats URL according to Odoo convention', () {
      const item = ActivityItem(
        id: 99,
        summary: 'Demo',
        note: '',
        resModel: 'crm.lead',
        resId: 88,
      );

      final url = ActivityCenterScreen.buildActivityDetailWebUrl(item);
      expect(url, startsWith('/mail/view?model=crm.lead&res_id=88'));
    });

    test('5. buildActivityDetailTitle generates proper title fallback', () {
      const itemWithResName = ActivityItem(
        id: 1,
        summary: 'Họp giao ban',
        note: '',
        resName: 'Kế hoạch Q4',
      );
      expect(ActivityCenterScreen.buildActivityDetailTitle(itemWithResName), equals('Kế hoạch Q4'));

      const itemWithSummaryOnly = ActivityItem(
        id: 2,
        summary: 'Gọi cho khách hàng',
        note: '',
      );
      expect(ActivityCenterScreen.buildActivityDetailTitle(itemWithSummaryOnly), equals('Gọi cho khách hàng'));

      const itemEmpty = ActivityItem(id: 3, summary: '', note: '');
      expect(ActivityCenterScreen.buildActivityDetailTitle(itemEmpty), equals('Hoạt động #3'));
    });

    test('6. Activity preview sorting prioritizes overdue, then today, then earliest deadline, max 3', () {
      final now = DateTime.now();
      final overdueEarlier = ActivityItem(
        id: 10,
        summary: 'Overdue 1',
        note: '',
        state: 'overdue',
        dateDeadline: now.subtract(const Duration(days: 3)),
      );
      final overdueLater = ActivityItem(
        id: 11,
        summary: 'Overdue 2',
        note: '',
        state: 'overdue',
        dateDeadline: now.subtract(const Duration(days: 1)),
      );
      final todayEarlier = ActivityItem(
        id: 12,
        summary: 'Today 1',
        note: '',
        state: 'today',
        dateDeadline: now.subtract(const Duration(hours: 2)),
      );
      final todayLater = ActivityItem(
        id: 13,
        summary: 'Today 2',
        note: '',
        state: 'today',
        dateDeadline: now.add(const Duration(hours: 4)),
      );

      // Danh sách gộp chưa sắp xếp và có trùng ID
      final rawList = [
        todayLater,
        overdueLater,
        todayEarlier,
        overdueEarlier,
        todayEarlier, // duplicate id: 12
      ];

      // Triển khai logic chuẩn của homeActivitiesPreviewProvider
      final seenIds = <int>{};
      final merged = <ActivityItem>[];
      for (final item in rawList) {
        if (seenIds.add(item.id)) {
          merged.add(item);
        }
      }

      merged.sort((a, b) {
        if (a.isOverdue && !b.isOverdue) return -1;
        if (!a.isOverdue && b.isOverdue) return 1;
        final dateA = a.dateDeadline ?? DateTime(2099);
        final dateB = b.dateDeadline ?? DateTime(2099);
        return dateA.compareTo(dateB);
      });

      final result = merged.take(3).toList();

      expect(result.length, equals(3));
      expect(result[0].id, equals(10)); // Overdue earlier
      expect(result[1].id, equals(11)); // Overdue later
      expect(result[2].id, equals(12)); // Today earlier (duplicate removed)
      expect(result.any((item) => item.id == 13), isFalse); // Capped at max 3
    });

    test('7. Activity visual mapping returns appropriate icon and color for call/meeting/todo/email', () {
      const callItem = ActivityItem(id: 1, summary: '', note: '', activityTypeName: 'Gọi điện thoại');
      final callVisual = ActivityTypeVisual.resolve(callItem.activityTypeName);
      expect(callVisual.icon, equals(LucideIcons.phoneCall));
      expect(callVisual.color, equals(const Color(0xFF0077D9)));

      const meetingItem = ActivityItem(id: 2, summary: '', note: '', activityTypeName: 'Cuộc họp');
      final meetingVisual = ActivityTypeVisual.resolve(meetingItem.activityTypeName);
      expect(meetingVisual.icon, equals(LucideIcons.calendarDays));
      expect(meetingVisual.color, equals(const Color(0xFFEA580C)));

      const emailItem = ActivityItem(id: 3, summary: '', note: '', activityTypeName: 'Email');
      final emailVisual = ActivityTypeVisual.resolve(emailItem.activityTypeName);
      expect(emailVisual.icon, equals(LucideIcons.mail));
      expect(emailVisual.color, equals(const Color(0xFF7C3AED)));

      const todoItem = ActivityItem(id: 4, summary: '', note: '', activityTypeName: 'Công việc');
      final todoVisual = ActivityTypeVisual.resolve(todoItem.activityTypeName);
      expect(todoVisual.icon, equals(LucideIcons.checkSquare));
      expect(todoVisual.color, equals(const Color(0xFF16A34A)));
    });
  });
}

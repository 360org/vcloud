import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/attendance/application/attendance_controller.dart';
import 'package:vcloud/features/attendance/presentation/attendance_history_screen.dart';
import 'package:vcloud/shared/models/attendance.dart';
import 'package:vcloud/shared/widgets/location_prompt_dialog.dart';

Widget _buildAttendanceHistoryApp(List<Attendance> attendances) {
  final router = GoRouter(
    initialLocation: '/attendance/history',
    routes: [
      GoRoute(
        path: '/attendance/history',
        builder: (context, state) => const AttendanceHistoryScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      attendanceStreamProvider.overrideWith((ref) => Stream.value(attendances)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 2.3: LocationPromptDialog Contract Tests', () {
    testWidgets('showLocationPromptDialog renders GPS title, prompt text and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showLocationPromptDialog(
                  context,
                  message: 'Cần bật GPS để xác thực vị trí chấm công.',
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Yêu cầu bật vị trí (GPS)'), findsOneWidget);
      expect(find.text('Cần bật GPS để xác thực vị trí chấm công.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.mapPin), findsOneWidget);
      expect(find.text('Đóng'), findsOneWidget);
      expect(find.text('Bật vị trí'), findsOneWidget);

      // Tapping 'Đóng' dismisses dialog
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      expect(find.text('Yêu cầu bật vị trí (GPS)'), findsNothing);
    });
  });

  group('Feature 2.8: AttendanceHistoryScreen Presentation Tests', () {
    testWidgets('Renders empty state when no attendance records exist for selected month', (tester) async {
      await tester.pumpWidget(_buildAttendanceHistoryApp(const <Attendance>[]));

      await tester.pumpAndSettle();

      expect(find.text('Lịch sử chấm công'), findsOneWidget);
      expect(find.text('Chưa có dữ liệu chấm công'), findsOneWidget);
      expect(find.text('Tải lại dữ liệu'), findsOneWidget);
      expect(find.byIcon(LucideIcons.calendarOff), findsOneWidget);
    });

    testWidgets('Renders attendance records and allows toggling calendar/list view', (tester) async {
      final now = DateTime.now();
      final dummyAttendances = <Attendance>[
        Attendance(
          id: '1',
          userId: '10',
          checkinTime: DateTime(now.year, now.month, 15, 8, 30),
          checkoutTime: DateTime(now.year, now.month, 15, 17, 30),
          createdAt: DateTime(now.year, now.month, 15, 8, 30),
        ),
        Attendance(
          id: '2',
          userId: '10',
          checkinTime: DateTime(now.year, now.month, 16, 8, 25),
          checkoutTime: DateTime(now.year, now.month, 16, 17, 35),
          createdAt: DateTime(now.year, now.month, 16, 8, 25),
        ),
      ];

      await tester.pumpWidget(_buildAttendanceHistoryApp(dummyAttendances));

      await tester.pumpAndSettle();

      // Attendance history screen renders without error
      expect(find.text('Lịch sử chấm công'), findsOneWidget);
      expect(find.text('Chưa có dữ liệu chấm công'), findsNothing);

      // Toggle to calendar view
      final toggleViewButton = find.byTooltip('Xem dạng lịch');
      expect(toggleViewButton, findsOneWidget);
      await tester.tap(toggleViewButton);
      await tester.pumpAndSettle();

      // Now tooltip changes to list view
      expect(find.byTooltip('Xem dạng danh sách'), findsOneWidget);
    });
  });
}

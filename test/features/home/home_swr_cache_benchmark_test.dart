import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/features/attendance/application/attendance_controller.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/home/application/home_summary_controller.dart';
import 'package:vcloud/features/home/data/dashboard_repository.dart';
import 'package:vcloud/features/ticket/application/ticket_controller.dart';
import 'package:vcloud/features/timesheet/application/timesheet_controller.dart';
import 'package:vcloud/shared/models/attendance.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._user);
  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}

class _FakeChannelsNotifier extends ChatV2ChannelsNotifier {
  @override
  Future<List<ChatV2Channel>> build() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 4.5: Dashboard SWR Cache Benchmark (<100ms Latency)', () {
    test('MobileDashboardSummary parses cached snapshot and merges fallback values synchronously', () {
      final cachedJson = {
        'attendance': {
          'is_checked_in': true,
          'today_attendance_minutes': 240,
        },
        'timesheet': {
          'today_minutes': 240,
        },
        'tickets': {
          'open_count': 5,
        },
        'chat': {
          'recent_conversation_count': 12,
          'unread_count': 3,
        },
      };

      final sw = Stopwatch()..start();
      final summary = MobileDashboardSummary.fromMap(cachedJson);
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(10));
      expect(summary.isCheckedIn, isTrue);
      expect(summary.todayMinutes, 240);
      expect(summary.openTickets, 5);
      expect(summary.recentConversationCount, 12);
      expect(summary.unreadMessageCount, 3);
    });

    test('homeSummaryProvider resolves from in-memory cached state in under 100ms', () {
      const mockUser = AuthUser(
        id: '1',
        email: 'ceo@360.org.vn',
        userMetadata: {'name': 'Sếp Tân'},
      );

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => _FakeAuthController(mockUser)),
          attendanceTodayProvider.overrideWith((ref) => Stream.value(null)),
          attendanceStreamProvider.overrideWith((ref) => Stream.value(const <Attendance>[])),
          todayTotalMinutesProvider.overrideWith((ref) => 180),
          openTicketsCountProvider.overrideWith((ref) => 4),
          chatV2ChannelsProvider.overrideWith(() => _FakeChannelsNotifier()),
          chatV2TotalUnreadProvider.overrideWith((ref) => 2),
          mobileDashboardSummaryProvider.overrideWith(
            (ref) => Future.value(
              const MobileDashboardSummary(
                isCheckedIn: true,
                todayMinutes: 180,
                openTickets: 4,
                recentConversationCount: 8,
                unreadMessageCount: 2,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sw = Stopwatch()..start();
      final summary = container.read(homeSummaryProvider);
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(100), reason: 'SWR in-memory resolution must complete in <100ms');
      expect(summary, isNotNull);
      expect(summary?.userName, 'ceo@360.org.vn');
      expect(summary?.todayMinutes, 180);
      expect(summary?.openTickets, 4);
      expect(summary?.unreadMessageCount, 2);
    });
  });
}

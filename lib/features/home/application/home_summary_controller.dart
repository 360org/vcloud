import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/application/attendance_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../ticket/application/ticket_controller.dart';
import '../../timesheet/application/timesheet_controller.dart';
import '../../timesheet/application/timesheet_controller.dart';
import '../data/dashboard_repository.dart';

class HomeSummary {
  HomeSummary({
    required this.userId,
    required this.userName,
    required this.openAttendanceElapsed,
    required this.isCheckedIn,
    required this.lastCheckout,
    required this.todayMinutes,
    required this.openTickets,
    required this.recentConversationCount,
    required this.unreadMessageCount,
  });

  final String userId;
  final String userName;
  final Duration openAttendanceElapsed;
  final bool isCheckedIn;
  final DateTime? lastCheckout;
  final int todayMinutes;
  final int openTickets;
  final int recentConversationCount;
  final int unreadMessageCount;
}

/// Top-level summary for the dashboard cards.
final homeSummaryProvider = Provider<HomeSummary?>((ref) {
  final auth = ref.watch(authControllerProvider).valueOrNull;

  final openAttendance = ref.watch(openSessionProvider);
  final att = ref.watch(attendanceStreamProvider).valueOrNull;
  Duration elapsed = Duration.zero;
  DateTime? lastCheckout;
  final isCheckedIn = openAttendance != null;
  elapsed = openAttendance?.elapsed ?? Duration.zero;
  if (att != null && att.isNotEmpty) {
    for (final a in att) {
      final co = a.checkoutTime;
      if (co != null && (lastCheckout == null || co.isAfter(lastCheckout))) {
        lastCheckout = co;
      }
    }
  }

  final todayMinutes = ref.watch(todayTotalMinutesProvider);
  final openTickets = ref.watch(openTicketsCountProvider);

  return HomeSummary(
    userId: auth?.id ?? '',
    userName: auth?.email ?? '',
    openAttendanceElapsed: elapsed,
    isCheckedIn: isCheckedIn,
    lastCheckout: lastCheckout,
    todayMinutes: todayMinutes,
    openTickets: openTickets,
    recentConversationCount: 0,
    unreadMessageCount: 0,
  );
});

// team cation mark

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (_) => DashboardRepository(),
);

final mobileDashboardSummaryProvider =
    FutureProvider.autoDispose<MobileDashboardSummary>(
      (ref) => ref.read(dashboardRepositoryProvider).summary(),
    );

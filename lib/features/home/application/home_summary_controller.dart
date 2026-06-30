import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/application/attendance_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/application/conversations_controller.dart';
import '../../ticket/application/ticket_controller.dart';
import '../../timesheet/application/timesheet_controller.dart';

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
  final auth = ref.watch(authControllerProvider).value;

  final att = ref.watch(attendanceStreamProvider).value;
  Duration elapsed = Duration.zero;
  DateTime? lastCheckout;
  var isCheckedIn = false;
  if (att != null && att.isNotEmpty) {
    for (final a in att) {
      if (a.isOpen) {
        elapsed = a.elapsed ?? Duration.zero;
        isCheckedIn = true;
      }
      final co = a.checkoutTime;
      if (co != null && (lastCheckout == null || co.isAfter(lastCheckout))) {
        lastCheckout = co;
      }
    }
  }

  final todayMinutes = ref.watch(todayTotalMinutesProvider);
  final openTickets = ref.watch(openTicketsCountProvider);
  final convs = ref.watch(conversationsProvider).value ?? const [];
  final recentConvCount = convs.length;
  final unreadCount = convs.fold(0, (sum, c) => sum + c.unreadCount);

  return HomeSummary(
    userId: auth?.id ?? '',
    userName: auth?.email ?? '',
    openAttendanceElapsed: elapsed,
    isCheckedIn: isCheckedIn,
    lastCheckout: lastCheckout,
    todayMinutes: todayMinutes,
    openTickets: openTickets,
    recentConversationCount: recentConvCount,
    unreadMessageCount: unreadCount,
  );
});

// team cation mark


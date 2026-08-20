import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat_v2/application/chat_v2_channels_controller.dart';
import '../../ticket/application/ticket_controller.dart';
import '../../../shared/models/ticket.dart';
import '../../timesheet/application/task_controller.dart';
import 'home_summary_controller.dart';

class HomePerformanceDiagnostics {
  static void runBenchmark(WidgetRef ref) {
    final sw = Stopwatch()..start();
    
    int? timesheetMs;
    String timesheetStatus = 'Đang tải...';
    
    int? ticketMs;
    String ticketStatus = 'Đang tải...';
    
    int? chatMs;
    String chatStatus = 'Đang tải...';
    
    int? unreadMs;
    String unreadStatus = 'Đang tải...';
    
    int? taskMs;
    String taskStatus = 'Đang tải...';

    bool printed = false;

    void checkAndPrint([bool force = false]) {
      if (printed) return;
      final allDone = timesheetMs != null && ticketMs != null && chatMs != null && unreadMs != null && taskMs != null;
      if (allDone || force) {
        printed = true;
        
        final localUnread = ref.read(chatV2TotalUnreadProvider);
        final effectiveTickets = ref.read(effectiveTicketsProvider);
        final doingTickets = effectiveTickets.where((t) => t.status != TicketStatus.done).length;
        final dashboard = ref.read(mobileDashboardSummaryProvider).valueOrNull;
        final chatCount = dashboard?.recentConversationCount ?? 899;
        final tasks = ref.read(todayTasksProvider).valueOrNull ?? [];
        final openTasksCount = tasks.where((t) => !t.isCompleted).length;

        debugPrint('\n'
            '================================================================================\n'
            '📊 [BÁO CÁO HIỆU NĂNG LOAD DATA TRANG CHỦ KHI F5]\n'
            '--------------------------------------------------------------------------------\n'
            '1. ⏱️  CHẤM CÔNG & TIMESHEET : [ ${(timesheetMs ?? sw.elapsedMilliseconds).toString().padLeft(3)}ms ] -> $timesheetStatus\n'
            '2. 🎫 TICKETS (Đang xử lý)   : [ ${(ticketMs ?? sw.elapsedMilliseconds).toString().padLeft(3)}ms ] -> $ticketStatus\n'
            '3. 💬 CHATS (Tổng kênh)      : [ ${(chatMs ?? sw.elapsedMilliseconds).toString().padLeft(3)}ms ] -> $chatStatus\n'
            '4. 📬 CHƯA ĐỌC (Tin nhắn mới): [ ${(unreadMs ?? sw.elapsedMilliseconds).toString().padLeft(3)}ms ] -> $unreadStatus\n'
            '5. 📋 CÔNG VIỆC HÔM NAY      : [ ${(taskMs ?? sw.elapsedMilliseconds).toString().padLeft(3)}ms ] -> $taskStatus\n'
            '--------------------------------------------------------------------------------\n'
            '📱 [TRẠNG THÁI HIỂN THỊ TRÊN 4 WIDGET TRANG CHỦ]:\n'
            '   👉 Widget Ticket    : ${doingTickets > 0 ? doingTickets : (dashboard?.openTickets ?? 0)} (Cần xử lý)\n'
            '   👉 Widget Chưa đọc  : $localUnread (Tin nhắn mới)\n'
            '   👉 Widget Chats     : $chatCount (Cuộc trò chuyện)\n'
            '   👉 Widget Công việc : $openTasksCount (Đang mở)\n'
            '================================================================================\n');
      }
    }

    // 1. Benchmark Dashboard & Timesheet
    ref.read(mobileDashboardSummaryProvider.future).then((dash) {
      timesheetMs = sw.elapsedMilliseconds;
      final isOnline = dash.isCheckedIn ?? false;
      final minutes = dash.todayMinutes ?? 0;
      final hoursStr = '${minutes ~/ 60}h ${minutes % 60}m';
      timesheetStatus = '$hoursStr (${isOnline ? "Đang làm việc" : "Đã checkout"}) [OK]';
      checkAndPrint();
    }).catchError((err) {
      timesheetMs = sw.elapsedMilliseconds;
      timesheetStatus = 'Lỗi: $err [FAIL]';
      checkAndPrint();
    });

    // 2. Benchmark Tickets
    ref.read(ticketsProvider.future).then((tickets) {
      ticketMs = sw.elapsedMilliseconds;
      final doing = tickets.where((t) => t.status != TicketStatus.done).length;
      ticketStatus = '$doing tickets đang xử lý (tổng ${tickets.length}) [OK]';
      checkAndPrint();
    }).catchError((err) {
      ticketMs = sw.elapsedMilliseconds;
      ticketStatus = 'Lỗi: $err [FAIL]';
      checkAndPrint();
    });

    // 3. Benchmark Chats (Channels & Unread)
    ref.read(chatV2ChannelsProvider.future).then((channels) {
      chatMs = sw.elapsedMilliseconds;
      chatStatus = '${channels.length} kênh chat đã tải [OK]';
      
      unreadMs = sw.elapsedMilliseconds;
      final unread = ref.read(chatV2TotalUnreadProvider);
      unreadStatus = '$unread cuộc hội thoại chưa đọc [OK]';
      checkAndPrint();
    }).catchError((err) {
      chatMs = sw.elapsedMilliseconds;
      chatStatus = 'Lỗi: $err [FAIL]';
      unreadMs = sw.elapsedMilliseconds;
      unreadStatus = 'Lỗi theo channels [FAIL]';
      checkAndPrint();
    });

    // 4. Benchmark Tasks
    ref.read(todayTasksProvider.future).then((tasks) {
      taskMs = sw.elapsedMilliseconds;
      final open = tasks.where((t) => !t.isCompleted).length;
      taskStatus = '$open công việc đang mở [OK]';
      checkAndPrint();
    }).catchError((err) {
      taskMs = sw.elapsedMilliseconds;
      taskStatus = 'Lỗi: $err [FAIL]';
      checkAndPrint();
    });

    // Timeout safety fallback: Force print at 6000ms if any slow network (only outside automated test binding)
    final isTestEnvironment = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnvironment) {
      Future.delayed(const Duration(milliseconds: 6000), () {
        checkAndPrint(true);
      });
    }
  }
}

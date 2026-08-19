import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/home/data/dashboard_repository.dart';

void main() {
  group('Dual-Tier Metric & MobileDashboardSummary Tests', () {
    test('MobileDashboardSummary parses unread_chat_count and open_ticket_count accurately', () {
      final json = {
        'status': 'success',
        'open_ticket_count': 16,
        'unread_chat_count': 212,
        'total_channel_count': 899,
        'today_timesheet_hours': 3.5,
        'attendance': {'is_checked_in': true},
      };

      final summary = MobileDashboardSummary.fromMap(json);

      expect(summary.openTickets, 16);
      expect(summary.unreadMessageCount, 212);
      expect(summary.recentConversationCount, 899);
      expect(summary.isCheckedIn, true);
    });

    test('MobileDashboardSummary falls back gracefully on nested fields', () {
      final json = {
        'tickets': {'open': 5},
        'chat': {'unread_count': 12, 'channel_count': 50},
      };

      final summary = MobileDashboardSummary.fromMap(json);

      expect(summary.openTickets, 5);
      expect(summary.unreadMessageCount, 12);
      expect(summary.recentConversationCount, 50);
    });
  });
}

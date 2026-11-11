import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/activity/data/models/activity_item.dart';
import 'package:vcloud/features/home/data/dashboard_repository.dart';

void main() {
  group('1. Home Activity Center & Clock Icon Data Tests', () {
    test('1.1 MobileDashboardSummary parses pending_activities_count accurately', () {
      final json = {
        'status': 'success',
        'pending_activities_count': 7,
        'open_ticket_count': 12,
        'unread_chat_count': 5,
      };

      final summary = MobileDashboardSummary.fromMap(json);
      expect(summary.pendingActivitiesCount, 7);
      expect(summary.openTickets, 12);
      expect(summary.unreadMessageCount, 5);
    });

    test('1.2 MobileDashboardSummary parses pending_activities_count from fallback keys', () {
      final jsonA = {
        'activities_count': 4,
      };
      expect(MobileDashboardSummary.fromMap(jsonA).pendingActivitiesCount, 4);

      final jsonB = {
        'activities': {'pending_count': 9},
      };
      expect(MobileDashboardSummary.fromMap(jsonB).pendingActivitiesCount, 9);
    });

    test('1.3 ActivityItem correctly identifies overdue, today, and planned deadlines', () {
      final now = DateTime.now();
      final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final overdueDate = now.subtract(const Duration(days: 2));
      final overdueStr = '${overdueDate.year.toString().padLeft(4, '0')}-${overdueDate.month.toString().padLeft(2, '0')}-${overdueDate.day.toString().padLeft(2, '0')}';

      final plannedDate = now.add(const Duration(days: 3));
      final plannedStr = '${plannedDate.year.toString().padLeft(4, '0')}-${plannedDate.month.toString().padLeft(2, '0')}-${plannedDate.day.toString().padLeft(2, '0')}';

      final overdueItem = ActivityItem.fromJson({
        'id': 101,
        'summary': 'Gọi khách hàng',
        'date_deadline': overdueStr,
      });
      expect(overdueItem.isOverdue, isTrue);
      expect(overdueItem.isToday, isFalse);
      expect(overdueItem.isPlanned, isFalse);

      final todayItem = ActivityItem.fromJson({
        'id': 102,
        'summary': 'Họp giao ban',
        'date_deadline': todayStr,
      });
      expect(todayItem.isOverdue, isFalse);
      expect(todayItem.isToday, isTrue);
      expect(todayItem.isPlanned, isFalse);

      final plannedItem = ActivityItem.fromJson({
        'id': 103,
        'summary': 'Review hợp đồng',
        'date_deadline': plannedStr,
      });
      expect(plannedItem.isOverdue, isFalse);
      expect(plannedItem.isToday, isFalse);
      expect(plannedItem.isPlanned, isTrue);
    });

    test('1.4 ActivityItem fallback when date_deadline is null defaults to planned', () {
      final itemNoDate = ActivityItem.fromJson({
        'id': 104,
        'summary': 'Nhiệm vụ chưa có deadline',
      });
      expect(itemNoDate.isOverdue, isFalse);
      expect(itemNoDate.isToday, isFalse);
      expect(itemNoDate.isPlanned, isTrue);
    });
  });

  group('2. Call Hiding Architectural Verification Tests', () {
    test('2.1 MobileDashboardSummary returns null when activities count is not provided', () {
      final json = {'open_ticket_count': 0};
      final summary = MobileDashboardSummary.fromMap(json);
      expect(summary.pendingActivitiesCount, isNull);
    });
  });
}

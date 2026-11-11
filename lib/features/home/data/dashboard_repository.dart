import '../../../core/api/odoo_api_client.dart';

class MobileDashboardSummary {
  const MobileDashboardSummary({
    this.isCheckedIn,
    this.todayMinutes,
    this.openTickets,
    this.recentConversationCount,
    this.unreadMessageCount,
    this.pendingActivitiesCount,
  });

  final bool? isCheckedIn;
  final int? todayMinutes;
  final int? openTickets;
  final int? recentConversationCount;
  final int? unreadMessageCount;
  final int? pendingActivitiesCount;

  factory MobileDashboardSummary.fromMap(Map<String, dynamic> map) {
    final attendance = _mapOrEmpty(
      map['attendance'] ?? map['today_attendance'],
    );
    final timesheet = _mapOrEmpty(map['timesheet']);
    final tickets = _mapOrEmpty(map['tickets']);
    final chat = _mapOrEmpty(map['chat']);
    return MobileDashboardSummary(
      isCheckedIn: _boolOrNull(
        map['is_checked_in'] ??
            map['checked_in'] ??
            attendance['is_checked_in'] ??
            attendance['checked_in'],
      ),
      todayMinutes:
          _minutesOrNull(map['today_minutes']) ??
          _minutesOrNull(attendance['today_attendance_minutes']) ??
          _hoursToMinutes(attendance['today_worked_hours']) ??
          _minutesOrNull(timesheet['today_minutes']) ??
          _hoursToMinutes(map['today_hours'] ?? timesheet['today_hours'] ?? map['today_timesheet_hours']),
      openTickets: _intOrNull(
        map['open_ticket_count'] ??
            map['open_tickets'] ??
            tickets['open'] ??
            tickets['open_count'],
      ),
      recentConversationCount: _intOrNull(
        map['total_channel_count'] ??
            map['recent_conversation_count'] ??
            chat['recent_conversation_count'] ??
            chat['channel_count'],
      ),
      unreadMessageCount: _intOrNull(
        map['unread_chat_count'] ??
            map['unread_message_count'] ??
            chat['unread_count'],
      ),
      pendingActivitiesCount: _intOrNull(
        map['pending_activities_count'] ??
            map['activities_count'] ??
            map['pending_activities'] ??
            (map['activities'] is Map ? (map['activities'] as Map)['pending_count'] ?? (map['activities'] as Map)['count'] : null),
      ),
    );
  }

  static Map<String, dynamic> _mapOrEmpty(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static bool? _boolOrNull(Object? value) {
    if (value is bool) return value;
    if (value == null) return null;
    final text = value.toString().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }

  static int? _intOrNull(Object? value) {
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  static int? _minutesOrNull(Object? value) => _intOrNull(value);

  static int? _hoursToMinutes(Object? value) {
    if (value is num) return (value * 60).round();
    if (value == null) return null;
    final parsed = double.tryParse(value.toString());
    return parsed == null ? null : (parsed * 60).round();
  }
}

class DashboardRepository {
  DashboardRepository({OdooApiClient? client})
    : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  Future<MobileDashboardSummary> summary() async {
    final res = await _client.get('/api/v1/mobile/dashboard/summary');
    return MobileDashboardSummary.fromMap(
      Map<String, dynamic>.from(res as Map),
    );
  }
}

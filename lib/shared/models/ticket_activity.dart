import '../../../core/utils/html_text.dart';

class TicketActivity {
  const TicketActivity({
    required this.id,
    this.activityTypeId,
    this.activityTypeName,
    required this.summary,
    required this.note,
    this.dateDeadline,
    this.state,
    this.dateDone,
    this.userId,
    this.userName,
    this.createDate,
  });

  final int id;
  final int? activityTypeId;
  final String? activityTypeName;
  final String summary;
  final String note;
  final DateTime? dateDeadline;
  final String? state;
  final DateTime? dateDone;
  final int? userId;
  final String? userName;
  final DateTime? createDate;

  factory TicketActivity.fromMap(Map<String, dynamic> map) {
    return TicketActivity(
      id: (map['id'] as num).toInt(),
      activityTypeId:
          map['activity_type_id'] is num
              ? (map['activity_type_id'] as num).toInt()
              : null,
      activityTypeName: map['activity_type_name']?.toString(),
      summary: cleanHtmlText(map['summary']),
      note: cleanHtmlText(map['note']),
      dateDeadline:
          map['date_deadline'] != null
              ? DateTime.tryParse(map['date_deadline'].toString())
              : null,
      state: map['state']?.toString(),
      dateDone:
          map['date_done'] != null
              ? DateTime.tryParse(map['date_done'].toString())
              : null,
      userId:
          map['user_id'] is num ? (map['user_id'] as num).toInt() : null,
      userName: map['user_name']?.toString(),
      createDate:
          map['create_date'] != null
              ? DateTime.tryParse(map['create_date'].toString())
              : null,
    );
  }
}

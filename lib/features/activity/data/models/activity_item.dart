import '../../../../core/utils/html_text.dart';

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.summary,
    required this.note,
    this.dateDeadline,
    this.state,
    this.activityTypeId,
    this.activityTypeName,
    this.resModel,
    this.resId,
    this.resName,
    this.userName,
  });

  final int id;
  final String summary;
  final String note;
  final DateTime? dateDeadline;
  final String? state; // 'overdue', 'today', 'planned'
  final int? activityTypeId;
  final String? activityTypeName;
  final String? resModel;
  final int? resId;
  final String? resName;
  final String? userName;

  bool get isOverdue {
    if (state == 'overdue') return true;
    if (dateDeadline == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(
      dateDeadline!.year,
      dateDeadline!.month,
      dateDeadline!.day,
    );
    return deadlineDay.isBefore(today);
  }

  bool get isToday {
    if (state == 'today') return true;
    if (dateDeadline == null) return false;
    final now = DateTime.now();
    return dateDeadline!.year == now.year &&
        dateDeadline!.month == now.month &&
        dateDeadline!.day == now.day;
  }

  bool get isPlanned => !isOverdue && !isToday;

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    DateTime? deadline;
    final rawDeadline = json['date_deadline'] ?? json['dateDeadline'];
    if (rawDeadline != null && rawDeadline.toString().isNotEmpty) {
      deadline = DateTime.tryParse(rawDeadline.toString());
    }

    String? stateStr = (json['state'] ?? json['activity_state'])?.toString();
    if (stateStr == null || stateStr.isEmpty) {
      if (deadline != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final deadlineDay = DateTime(
          deadline.year,
          deadline.month,
          deadline.day,
        );
        if (deadlineDay.isBefore(today)) {
          stateStr = 'overdue';
        } else if (deadlineDay.isAtSameMomentAs(today)) {
          stateStr = 'today';
        } else {
          stateStr = 'planned';
        }
      } else {
        stateStr = 'planned';
      }
    }

    return ActivityItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      summary: cleanHtmlText(json['summary'] ?? json['display_name'] ?? ''),
      note: cleanHtmlText(json['note'] ?? ''),
      dateDeadline: deadline,
      state: stateStr,
      activityTypeId: (json['activity_type_id'] ?? json['activityTypeId']) is num
          ? ((json['activity_type_id'] ?? json['activityTypeId']) as num).toInt()
          : (json['activity_type_id'] is List &&
                  (json['activity_type_id'] as List).isNotEmpty
              ? (json['activity_type_id'][0] as num?)?.toInt()
              : null),
      activityTypeName:
          (json['activity_type_name'] ?? json['activityTypeName'])?.toString() ??
              (json['activity_type_id'] is List &&
                      (json['activity_type_id'] as List).length > 1
                  ? json['activity_type_id'][1]?.toString()
                  : null),
      resModel: (json['res_model'] ?? json['resModel'])?.toString(),
      resId: (json['res_id'] ?? json['resId']) is num
          ? ((json['res_id'] ?? json['resId']) as num).toInt()
          : null,
      resName: (json['res_name'] ?? json['resName'])?.toString(),
      userName: (json['user_name'] ?? json['userName'])?.toString() ??
          (json['user_id'] is List && (json['user_id'] as List).length > 1
              ? json['user_id'][1]?.toString()
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'summary': summary,
      'note': note,
      'date_deadline': dateDeadline?.toIso8601String(),
      'state': state,
      'activity_type_id': activityTypeId,
      'activity_type_name': activityTypeName,
      'res_model': resModel,
      'res_id': resId,
      'res_name': resName,
      'user_name': userName,
    };
  }
}

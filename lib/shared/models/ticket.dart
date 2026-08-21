import '../../core/api/mobile_attachment_repository.dart';

/// Whitelisted values for the `ticket_status` enum.
enum TicketStatus { todo, doing, done }

extension TicketStatusDb on TicketStatus {
  String get dbValue => switch (this) {
    TicketStatus.todo => 'Todo',
    TicketStatus.doing => 'Doing',
    TicketStatus.done => 'Done',
  };

  String get label => dbValue;

  bool get isOpen => this != TicketStatus.done;

  static TicketStatus fromDb(Object? value) {
    if (value == null || value == false) return TicketStatus.todo;
    final str = value.toString().toLowerCase().trim();
    if (str == 'done' ||
        str == 'completed' ||
        str == 'solved' ||
        str.contains('done') ||
        str.contains('solved') ||
        str.contains('hoàn thành') ||
        str.contains('đã giải quyết')) {
      return TicketStatus.done;
    }
    if (str == 'doing' ||
        str == 'in_progress' ||
        str == 'take' ||
        str.contains('doing') ||
        str.contains('progress') ||
        str.contains('đang xử lý')) {
      return TicketStatus.doing;
    }
    return TicketStatus.todo;
  }
}

/// Ticket priority levels.
enum TicketPriority { p1, p2, p3, p4 }

extension TicketPriorityDb on TicketPriority {
  String get dbValue => switch (this) {
    TicketPriority.p1 => 'P1',
    TicketPriority.p2 => 'P2',
    TicketPriority.p3 => 'P3',
    TicketPriority.p4 => 'P4',
  };

  String get label => dbValue;

  String get displayName => switch (this) {
    TicketPriority.p1 => 'Khẩn cấp',
    TicketPriority.p2 => 'Cao',
    TicketPriority.p3 => 'Bình thường',
    TicketPriority.p4 => 'Thấp',
  };

  static TicketPriority fromDb(String v) {
    return TicketPriority.values.firstWhere(
      (p) => p.dbValue == v,
      orElse: () => TicketPriority.p3,
    );
  }
}

/// Filter options for fetching/filtering tickets.
class TicketFilter {
  const TicketFilter({
    this.priority,
    this.teamId,
  });

  final TicketPriority? priority;
  final int? teamId;

  bool get isEmpty => priority == null && teamId == null;

  TicketFilter copyWith({
    Object? priority = _sentinel,
    Object? teamId = _sentinel,
  }) => TicketFilter(
    priority: priority == _sentinel ? this.priority : priority as TicketPriority?,
    teamId: teamId == _sentinel ? this.teamId : teamId as int?,
  );

  static const _sentinel = Object();
}

/// Row from `public.tickets`.
class Ticket {
  const Ticket({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.createdBy,
    required this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.deadline,
    this.priority = TicketPriority.p3,
    this.category,
    this.tagLabels = const <String>[],
    this.attachments = const <MobileAttachment>[],
  });

  final String id;
  final String title;
  final String? description;
  final TicketStatus status;
  final String createdBy;
  final String assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deadline;
  final TicketPriority priority;
  final String? category;
  final List<String> tagLabels;
  final List<MobileAttachment> attachments;

  bool get isOverdue {
    if (status == TicketStatus.done) return false;
    final target = deadline ?? createdAt;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(target.year, target.month, target.day);
    return targetDay.isBefore(todayStart);
  }

  Ticket copyWith({
    TicketStatus? status,
    TicketPriority? priority,
    String? category,
    List<String>? tagLabels,
    DateTime? deadline,
    List<MobileAttachment>? attachments,
  }) => Ticket(
    id: id,
    title: title,
    description: description,
    status: status ?? this.status,
    createdBy: createdBy,
    assignedTo: assignedTo,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deadline: deadline ?? this.deadline,
    priority: priority ?? this.priority,
    category: category ?? this.category,
    tagLabels: tagLabels ?? this.tagLabels,
    attachments: attachments ?? this.attachments,
  );

  factory Ticket.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'] ?? map['ticket_ref'] ?? '';
    final rawTitle = map['title'] ?? map['name'] ?? map['subject'] ?? 'Ticket';
    final rawCreatedBy = map['created_by'] ?? map['create_uid'] ?? '';
    final rawAssignedTo = map['assigned_to'] ?? map['user_id'] ?? '';
    final rawCreatedAt = map['created_at'] ?? map['create_date'];
    final rawUpdatedAt = map['updated_at'] ?? map['write_date'] ?? rawCreatedAt;
    final rawDeadline = map['date_deadline'] ?? map['deadline'];

    final rawAttachments = map['attachments'];
    final attachmentsList = <MobileAttachment>[];
    if (rawAttachments is List) {
      for (final item in rawAttachments) {
        if (item is Map) {
          try {
            attachmentsList.add(MobileAttachment.fromMap(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
    }

    return Ticket(
      id: rawId.toString(),
      title: rawTitle.toString(),
      description: _parseString(map['description']),
      status: TicketStatusDb.fromDb((map['status'] ?? map['stage_id'] ?? 'open').toString()),
      createdBy: rawCreatedBy.toString(),
      assignedTo: rawAssignedTo.toString(),
      createdAt: _parseDate(rawCreatedAt),
      updatedAt: _parseDate(rawUpdatedAt),
      deadline: rawDeadline != null && rawDeadline != false ? _parseDate(rawDeadline) : null,
      priority: map['priority'] != null
          ? TicketPriorityDb.fromDb(map['priority'].toString())
          : TicketPriority.p3,
      category: _parseString(map['category'] ?? map['team_id']),
      tagLabels: (map['tag_labels'] as List? ?? const <dynamic>[])
          .map((tag) => tag.toString())
          .where((tag) => tag.isNotEmpty)
          .toList(),
      attachments: attachmentsList,
    );
  }

  static String? _parseString(Object? value) {
    if (value == null || value == false) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime _parseDate(Object? value) {
    if (value == null || value == false) return DateTime.now();
    if (value is DateTime) {
      final utc = value.isUtc ? value : value.toUtc();
      return utc.toLocal();
    }
    final text = value.toString();
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return DateTime.now();
    final utcDt = (parsed.isUtc || _hasTimezone(text))
        ? parsed.toUtc()
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
            parsed.microsecond,
          );
    return utcDt.toLocal();
  }

  static bool _hasTimezone(String value) {
    return value.endsWith('Z') ||
        value.contains('+') ||
        (value.contains('-') && value.lastIndexOf('-') > 10);
  }
}

class TicketTeamOption {
  const TicketTeamOption({required this.id, required this.name});

  final int id;
  final String name;

  factory TicketTeamOption.fromMap(Map<String, dynamic> map) =>
      TicketTeamOption(
        id: (map['id'] as num).toInt(),
        name: (map['name'] ?? '').toString(),
      );
}

class TicketTagOption {
  const TicketTagOption({this.id, required this.name});

  final int? id;
  final String name;

  factory TicketTagOption.fromMap(Map<String, dynamic> map) =>
      TicketTagOption(
        id: (map['id'] as num?)?.toInt(),
        name: (map['name'] ?? '').toString(),
      );
}

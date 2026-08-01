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

  static TicketStatus fromDb(String v) {
    return TicketStatus.values.firstWhere(
      (s) => s.dbValue == v,
      orElse: () => TicketStatus.todo,
    );
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
    this.priority = TicketPriority.p3,
    this.category,
    this.tagLabels = const <String>[],
  });

  final String id;
  final String title;
  final String? description;
  final TicketStatus status;
  final String createdBy;
  final String assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TicketPriority priority;
  final String? category;
  final List<String> tagLabels;

  Ticket copyWith({
    TicketStatus? status,
    TicketPriority? priority,
    String? category,
    List<String>? tagLabels,
  }) => Ticket(
    id: id,
    title: title,
    description: description,
    status: status ?? this.status,
    createdBy: createdBy,
    assignedTo: assignedTo,
    createdAt: createdAt,
    updatedAt: updatedAt,
    priority: priority ?? this.priority,
    category: category ?? this.category,
    tagLabels: tagLabels ?? this.tagLabels,
  );

  factory Ticket.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'] ?? map['ticket_ref'] ?? '';
    final rawTitle = map['title'] ?? map['name'] ?? map['subject'] ?? 'Ticket';
    final rawCreatedBy = map['created_by'] ?? map['create_uid'] ?? '';
    final rawAssignedTo = map['assigned_to'] ?? map['user_id'] ?? '';
    final rawCreatedAt = map['created_at'] ?? map['create_date'];
    final rawUpdatedAt = map['updated_at'] ?? map['write_date'] ?? rawCreatedAt;

    return Ticket(
      id: rawId.toString(),
      title: rawTitle.toString(),
      description: _parseString(map['description']),
      status: TicketStatusDb.fromDb((map['status'] ?? map['stage_id'] ?? 'open').toString()),
      createdBy: rawCreatedBy.toString(),
      assignedTo: rawAssignedTo.toString(),
      createdAt: _parseDate(rawCreatedAt),
      updatedAt: _parseDate(rawUpdatedAt),
      priority: map['priority'] != null
          ? TicketPriorityDb.fromDb(map['priority'].toString())
          : TicketPriority.p3,
      category: _parseString(map['category'] ?? map['team_id']),
      tagLabels: (map['tag_labels'] as List? ?? const <dynamic>[])
          .map((tag) => tag.toString())
          .where((tag) => tag.isNotEmpty)
          .toList(),
    );
  }

  static String? _parseString(Object? value) {
    if (value == null || value == false) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime _parseDate(Object? value) {
    if (value == null || value == false) return DateTime.now();
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
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

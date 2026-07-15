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

  factory Ticket.fromMap(Map<String, dynamic> map) => Ticket(
    id: map['id'] as String,
    title: map['title'] as String,
    description: map['description'] as String?,
    status: TicketStatusDb.fromDb(map['status'] as String),
    createdBy: map['created_by'] as String,
    assignedTo: map['assigned_to'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    priority: map['priority'] != null
        ? TicketPriorityDb.fromDb(map['priority'] as String)
        : TicketPriority.p3,
    category: map['category'] as String?,
    tagLabels: (map['tag_labels'] as List? ?? const <dynamic>[])
        .map((tag) => tag.toString())
        .where((tag) => tag.isNotEmpty)
        .toList(),
  );
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

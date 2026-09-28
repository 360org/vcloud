/// A subtask item in a task's checklist.
class TaskChecklistItem {
  const TaskChecklistItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final bool isCompleted;

  TaskChecklistItem copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return TaskChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'is_completed': isCompleted,
  };

  factory TaskChecklistItem.fromMap(Map<String, dynamic> map) => TaskChecklistItem(
    id: (map['id'] ?? '').toString(),
    title: (map['title'] ?? map['name'] ?? '').toString(),
    isCompleted: map['is_completed'] == true ||
        map['is_done'] == true ||
        (map['is_completed'] is String && map['is_completed'] == 'true'),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskChecklistItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode => Object.hash(id, title, isCompleted);
}

/// Computes completion percentage based on formula: `(completed / total) * 100%`.
/// Returns `0.0` when [items] is empty.
double calculateSubtaskProgress(List<TaskChecklistItem> items) {
  if (items.isEmpty) return 0.0;
  final completed = items.where((item) => item.isCompleted).length;
  return (completed / items.length) * 100.0;
}

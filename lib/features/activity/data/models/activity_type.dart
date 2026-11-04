class ActivityType {
  const ActivityType({
    required this.id,
    required this.name,
    this.summary,
    this.icon,
  });

  final int id;
  final String name;
  final String? summary;
  final String? icon;

  factory ActivityType.fromJson(Map<String, dynamic> json) {
    return ActivityType(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      summary: json['summary']?.toString(),
      icon: json['icon']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'summary': summary,
      'icon': icon,
    };
  }
}

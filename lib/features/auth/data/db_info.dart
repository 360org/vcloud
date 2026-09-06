/// Thông tin Database/Instance từ Master Directory Lookup.
class DbInfo {
  const DbInfo({
    required this.login,
    required this.databaseName,
    required this.databaseUrl,
    this.projectId,
  });

  final String login;
  final String databaseName;
  final String databaseUrl;
  final dynamic projectId;

  String get displayName =>
      databaseName.isNotEmpty ? databaseName : databaseUrl;

  factory DbInfo.fromJson(Map<String, dynamic> json) {
    return DbInfo(
      login: (json['login'] as String?) ?? '',
      databaseName: (json['database_name'] as String?) ??
          (json['db'] as String?) ??
          (json['database'] as String?) ??
          '',
      databaseUrl: (json['database_url'] as String?) ??
          (json['url'] as String?) ??
          (json['base_url'] as String?) ??
          '',
      projectId: json['project_id'],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'login': login,
        'database_name': databaseName,
        'database_url': databaseUrl,
        if (projectId != null) 'project_id': projectId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DbInfo &&
          runtimeType == other.runtimeType &&
          databaseName == other.databaseName &&
          databaseUrl == other.databaseUrl;

  @override
  int get hashCode => databaseName.hashCode ^ databaseUrl.hashCode;
}

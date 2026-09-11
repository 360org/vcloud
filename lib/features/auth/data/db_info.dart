/// Thông tin Database/Instance từ Master Directory Lookup.
class DbInfo {
  const DbInfo({
    required this.login,
    required this.databaseName,
    required this.databaseUrl,
    this.displayName,
    this.projectId,
    this.hasVMobile = true,
  });

  final String login;
  final String databaseName;
  final String databaseUrl;
  final String? displayName;
  final dynamic projectId;
  final bool hasVMobile;

  String get effectiveDisplayName {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    return databaseName.isNotEmpty ? databaseName : databaseUrl;
  }

  /// Nhãn phân biệt [Nội bộ / Khách hàng] và phiên bản Odoo [17 / 19]
  String get categoryLabel {
    final lowerDb = databaseName.toLowerCase();
    final lowerUrl = databaseUrl.toLowerCase();

    final is19 = lowerDb.contains('19') ||
        lowerUrl.contains(':1900') ||
        lowerUrl.contains(':8079') ||
        lowerUrl.contains('demo.vuahethong');
    final isCustomer = lowerDb.contains('client') || lowerDb.contains('kh');

    if (is19) {
      return isCustomer ? '👥 Khách Hàng (Odoo 19)' : '🏢 Nội Bộ (Odoo 19)';
    } else if (isCustomer) {
      return '👥 Khách Hàng (Odoo 17)';
    } else {
      return '🏢 Nội Bộ (Odoo 17)';
    }
  }

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
      displayName: (json['display_name'] as String?) ??
          (json['name'] as String?),
      projectId: json['project_id'],
      hasVMobile: (json['has_v_mobile'] as bool?) ??
          (json['has_vmobile'] as bool?) ??
          true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'login': login,
        'database_name': databaseName,
        'database_url': databaseUrl,
        if (displayName != null) 'display_name': displayName,
        if (projectId != null) 'project_id': projectId,
        'has_v_mobile': hasVMobile,
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

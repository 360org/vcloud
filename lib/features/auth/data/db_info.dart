/// Thông tin Database/Instance từ Master Directory Lookup.
class DbInfo {
  const DbInfo({
    required this.login,
    required this.databaseName,
    required this.databaseUrl,
    this.displayName,
    this.projectId,
    this.hasVMobile = true,
    this.rawCategoryLabel,
  });

  final String login;
  final String databaseName;
  final String databaseUrl;
  final String? displayName;
  final dynamic projectId;
  final bool hasVMobile;
  final String? rawCategoryLabel;

  String get effectiveDisplayName {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    return databaseName.isNotEmpty ? databaseName : databaseUrl;
  }

  /// Nhãn phân biệt [Nội bộ / Khách hàng]
  /// Theo chỉ đạo của Sếp Tân: Bỏ đuôi hiển thị "(Odoo 17)" / "(Odoo 19)".
  String get categoryLabel {
    // 1. Ưu tiên lấy trực tiếp nhãn do Master Hub / Backend trả về
    if (rawCategoryLabel != null && rawCategoryLabel!.trim().isNotEmpty) {
      final clean = rawCategoryLabel!.trim();
      final lower = clean.toLowerCase();
      if (lower.contains('khách hàng') || lower.contains('client')) {
        return '👥 Khách Hàng';
      }
      if (lower.contains('nội bộ') || lower.contains('internal')) {
        return '🏢 Nội Bộ';
      }
      return clean;
    }

    // 2. Fallback heuristic theo tên database và URL
    final lowerDb = databaseName.toLowerCase();
    final isCustomer = lowerDb.contains('client') || lowerDb.contains('kh');

    return isCustomer ? '👥 Khách Hàng' : '🏢 Nội Bộ';
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
      rawCategoryLabel: (json['category_label'] as String?) ??
          (json['category'] as String?),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'login': login,
        'database_name': databaseName,
        'database_url': databaseUrl,
        if (displayName != null) 'display_name': displayName,
        if (projectId != null) 'project_id': projectId,
        'has_v_mobile': hasVMobile,
        if (rawCategoryLabel != null) 'category_label': rawCategoryLabel,
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

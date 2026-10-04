class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.userMetadata = const <String, dynamic>{},
  });

  final String id;
  final String? email;
  final Map<String, dynamic> userMetadata;

  bool get isPortal =>
      userMetadata['is_portal'] == true ||
      userMetadata['share'] == true ||
      userMetadata['user_type'] == 'portal';

  Map<String, dynamic> get installedModules {
    final raw = userMetadata['installed_modules'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  bool get hasHelpdesk => installedModules['helpdesk'] == true;
  bool get hasTimesheet => installedModules['hr_timesheet'] == true;
  bool get hasAttendance => installedModules['hr_attendance'] == true;
  bool get hasProject => installedModules['project'] == true;
}

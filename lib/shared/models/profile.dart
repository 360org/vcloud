/// Mirrors the `public.profiles` table.
///
/// We use plain classes with `fromJson`/`toJson` to keep the MVP free
/// of code generation overhead. If/when the schema stabilizes we can
/// migrate to freezed without changing call sites.
class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.role = 'customer',
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String role;

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        email: map['email'] as String,
        displayName: map['display_name'] as String? ?? '',
        avatarUrl: map['avatar_url'] as String?,
        role: map['role'] as String? ?? 'customer',
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'role': role,
      };

  String get initials {
    final cleaned = displayName.trim();
    if (cleaned.isEmpty) return email.isNotEmpty ? email[0].toUpperCase() : '?';
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool get isCustomer => role == 'customer';
  bool get isStaff => role == 'staff' || role == 'admin';
  bool get isAdmin => role == 'admin';
}

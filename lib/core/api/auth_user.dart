class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.userMetadata = const <String, dynamic>{},
  });

  final String id;
  final String? email;
  final Map<String, dynamic> userMetadata;
}

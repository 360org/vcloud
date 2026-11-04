class OdooSession {
  const OdooSession({
    required this.accessToken,
    required this.uid,
    required this.db,
    required this.login,
    required this.expiresAt,
    required this.baseUrl,
    this.refreshToken,
    this.tenantId,
    this.scope,
    this.partnerId,
    this.sessionId,
  });

  final String accessToken;
  final String? refreshToken;
  final int uid;
  final String db;
  final String login;
  final DateTime expiresAt;
  final String baseUrl;
  final int? tenantId;
  final String? scope;
  final int? partnerId;
  final String? sessionId;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'access_token': accessToken,
    'uid': uid,
    'db': db,
    'login': login,
    'expires_at': expiresAt.toIso8601String(),
    'base_url': baseUrl,
    if (refreshToken != null) 'refresh_token': refreshToken,
    if (tenantId != null) 'tenant_id': tenantId,
    if (scope != null) 'scope': scope,
    if (partnerId != null) 'partner_id': partnerId,
    if (sessionId != null) 'session_id': sessionId,
  };

  factory OdooSession.fromJson(Map<String, dynamic> json) => OdooSession(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String?,
    uid: json['uid'] as int,
    db: json['db'] as String,
    login: json['login'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
    baseUrl: (json['base_url'] as String?) ?? '',
    tenantId: (json['tenant_id'] as num?)?.toInt(),
    scope: json['scope'] as String?,
    partnerId: (json['partner_id'] as num?)?.toInt(),
    sessionId: json['session_id'] as String?,
  );

  OdooSession copyWith({
    String? accessToken,
    String? refreshToken,
    int? uid,
    String? db,
    String? login,
    DateTime? expiresAt,
    String? baseUrl,
    int? tenantId,
    String? scope,
    int? partnerId,
    String? sessionId,
  }) => OdooSession(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    uid: uid ?? this.uid,
    db: db ?? this.db,
    login: login ?? this.login,
    expiresAt: expiresAt ?? this.expiresAt,
    baseUrl: baseUrl ?? this.baseUrl,
    tenantId: tenantId ?? this.tenantId,
    scope: scope ?? this.scope,
    partnerId: partnerId ?? this.partnerId,
    sessionId: sessionId ?? this.sessionId,
  );
}

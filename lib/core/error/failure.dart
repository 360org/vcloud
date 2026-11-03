/// Lightweight failure type passed up from repositories.
///
/// We deliberately avoid either/result libraries for the MVP; a simple
/// [String] message is enough to drive UI snackbars / banners.
class Failure implements Exception {
  Failure(this.message, {this.cause, this.statusCode});

  final String message;
  final Object? cause;
  final int? statusCode;

  @override
  String toString() => 'Failure($message)';
}

/// Thất bại do tài khoản yêu cầu xác thực hai lớp (2FA / TOTP)
class MfaRequiredFailure extends Failure {
  MfaRequiredFailure({
    required this.login,
    required this.db,
    required this.targetBaseUrl,
    this.mfaType = 'totp',
    String message = 'Tài khoản đã kích hoạt bảo mật hai lớp. Vui lòng nhập mã OTP.',
  }) : super(message);

  final String login;
  final String db;
  final String targetBaseUrl;
  final String mfaType;

  @override
  String toString() => 'MfaRequiredFailure(login: $login, db: $db, mfaType: $mfaType)';
}

String describeError(Object e) {
  if (e is Failure) return e.message;
  return e.toString();
}

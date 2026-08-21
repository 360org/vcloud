/// Lightweight failure type passed up from repositories.
///
/// We deliberately avoid either/result libraries for the MVP; a simple
/// [String] message is enough to drive UI snackbars / banners.
class Failure implements Exception {
  Failure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'Failure($message)';
}

String describeError(Object e) {
  if (e is Failure) return e.message;
  return e.toString();
}

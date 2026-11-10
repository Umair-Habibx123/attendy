/// An error with a message that's safe to show to the user.
class AppException implements Exception {
  const AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

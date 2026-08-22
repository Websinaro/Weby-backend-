/// Normalized error shape surfaced to the UI, regardless of whether it
/// came from a network failure, a validation error, or a backend error
/// response using the { success:false, error:{code,message} } envelope.
class ApiException implements Exception {
  ApiException({required this.message, this.code = 'UNKNOWN_ERROR', this.statusCode});

  final String message;
  final String code;
  final int? statusCode;

  bool get isAuthError =>
      code == 'UNAUTHORIZED' || code == 'TOKEN_INVALID' || code == 'SESSION_INVALID';

  @override
  String toString() => message;
}

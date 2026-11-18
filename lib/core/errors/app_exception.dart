/// Base exception class for low-level technical errors across data sources.
sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType(code: $code, message: $message, cause: $cause)';
}

final class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.cause});
}

final class ServerException extends AppException {
  const ServerException(
    super.message, {
    this.statusCode,
    super.code,
    super.cause,
  });

  final int? statusCode;
}

final class CacheException extends AppException {
  const CacheException(super.message, {super.code, super.cause});
}

final class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.cause});
}

final class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.cause});
}

final class ServiceUnavailableException extends AppException {
  const ServiceUnavailableException(super.message, {super.code, super.cause});
}

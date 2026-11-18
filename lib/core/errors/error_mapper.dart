import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import 'app_exception.dart';
import 'failure.dart';

/// Translates infrastructure exceptions into typed domain [Failure] instances.
abstract final class ErrorMapper {
  static Failure mapException(Object error) {
    if (error is Failure) {
      return error;
    }

    if (error is AppException) {
      return switch (error) {
        NetworkException() => NetworkFailure(error.message, code: error.code),
        ServerException() => ServerFailure(
            error.message,
            statusCode: error.statusCode,
            code: error.code,
          ),
        CacheException() => CacheFailure(error.message, code: error.code),
        AuthException() => AuthFailure(error.message, code: error.code),
        ValidationException() =>
          ValidationFailure(error.message, code: error.code),
        ServiceUnavailableException() => ModelNotIntegratedFailure(
            error.message,
          ),
      };
    }

    if (error is DioException) {
      return _mapDioException(error);
    }

    if (error is DatabaseException) {
      return const CacheFailure(
        'A local database error occurred while accessing offline records.',
      );
    }

    return UnexpectedFailure(
      'An unexpected error occurred. Please try again. (${error.runtimeType})',
    );
  }

  static Failure _mapDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkFailure(
          'The request timed out. Check your connection and try again.',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return const NetworkFailure(
          'Unable to reach the FixWise server. Check your network connection or server URL.',
          code: 'CONNECTION_ERROR',
        );
      case DioExceptionType.badResponse:
        final statusCode = exception.response?.statusCode;
        final serverMessage = _extractServerMessage(exception.response?.data);
        if (statusCode == 401 || statusCode == 403) {
          return AuthFailure(
            serverMessage ?? 'Your session has expired. Please sign in again.',
            code: 'HTTP_$statusCode',
          );
        }
        return ServerFailure(
          serverMessage ??
              'The server returned an error (HTTP ${statusCode ?? 'unknown'}).',
          statusCode: statusCode,
          code: 'HTTP_${statusCode ?? 'ERROR'}',
        );
      case DioExceptionType.cancel:
        return const NetworkFailure(
          'The request was cancelled.',
          code: 'CANCELLED',
        );
      case DioExceptionType.badCertificate:
        return const NetworkFailure(
          'Secure connection could not be verified (invalid TLS certificate).',
          code: 'BAD_CERTIFICATE',
        );
      case DioExceptionType.unknown:
        return NetworkFailure(
          exception.message ?? 'A network error occurred. Please try again.',
        );
    }
  }

  static String? _extractServerMessage(Object? data) {
    if (data is Map<String, dynamic>) {
      final candidate = data['message'] ?? data['detail'] ?? data['error'];
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }
}

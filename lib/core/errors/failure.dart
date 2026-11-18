/// Domain-level failure representations exposed to controllers and UI layers.
sealed class Failure {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

final class NetworkFailure extends Failure {
  const NetworkFailure(
    super.message, {
    super.code = 'NETWORK_ERROR',
  });
}

final class ServerFailure extends Failure {
  const ServerFailure(
    super.message, {
    this.statusCode,
    super.code = 'SERVER_ERROR',
  });

  final int? statusCode;
}

final class CacheFailure extends Failure {
  const CacheFailure(
    super.message, {
    super.code = 'LOCAL_STORAGE_ERROR',
  });
}

final class AuthFailure extends Failure {
  const AuthFailure(
    super.message, {
    super.code = 'AUTH_ERROR',
  });
}

final class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    super.code = 'VALIDATION_ERROR',
  });
}

final class ModelNotIntegratedFailure extends Failure {
  const ModelNotIntegratedFailure([
    super.message =
        'The AI fault diagnosis service is not configured yet. Configure a backend inference URL in Profile settings or integrate the ML model in the next stage.',
  ]) : super(code: 'MODEL_NOT_INTEGRATED');
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(
    super.message, {
    super.code = 'UNEXPECTED_ERROR',
  });
}

/// Functional result wrapper to avoid uncaught exceptions in presentation logic.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is ErrorResult<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failure,
  }) {
    return switch (this) {
      Success<T>(data: final value) => success(value),
      ErrorResult<T>(failure: final err) => failure(err),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

final class ErrorResult<T> extends Result<T> {
  const ErrorResult(this.failure);

  final Failure failure;
}

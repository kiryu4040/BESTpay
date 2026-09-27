import '../errors/app_error.dart';

/// Represents either a successful value or a structured application failure.
sealed class AppResult<T> {
  const AppResult();

  bool get isSuccess => switch (this) {
        AppSuccess<T>() => true,
        AppFailure<T>() => false,
      };

  bool get isFailure => !isSuccess;

  /// Transforms a successful value without changing a failure.
  ///
  /// Exceptions thrown by [transform] are intentionally not caught.
  AppResult<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      AppSuccess<T>(value: final value) => AppSuccess<R>(transform(value)),
      AppFailure<T>(error: final error) => AppFailure<R>(error),
    };
  }

  /// Produces one value by handling exactly one of the two result states.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppError error) onFailure,
  }) {
    return switch (this) {
      AppSuccess<T>(value: final value) => onSuccess(value),
      AppFailure<T>(error: final error) => onFailure(error),
    };
  }
}

/// A successful [AppResult] containing exactly one value.
final class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);

  final T value;
}

/// A failed [AppResult] containing exactly one structured error.
final class AppFailure<T> extends AppResult<T> {
  const AppFailure(this.error);

  final AppError error;
}

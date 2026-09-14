import 'app_error_code.dart';

/// A structured failure that is safe to pass across application layers.
///
/// User-facing text, logging, and crash reporting are separate concerns.
final class AppError {
  AppError({
    required this.code,
    required this.operation,
    this.retryable = false,
    Map<String, Object?> context = const <String, Object?>{},
    this.safeMessage,
    this.debugMessage,
    this.causeType,
    this.occurredAt,
  }) : context = Map<String, Object?>.unmodifiable(context);

  final AppErrorCode code;
  final String operation;
  final bool retryable;

  /// A defensive, unmodifiable copy containing only safe diagnostic values.
  final Map<String, Object?> context;

  /// An optional explanation that must not contain sensitive information.
  final String? safeMessage;

  /// Developer-only information that must never be shown directly to users.
  final String? debugMessage;

  /// The exception type name only; the raw exception is intentionally omitted.
  final String? causeType;

  /// The time at which the error occurred, when supplied by the caller.
  final DateTime? occurredAt;

  @override
  String toString() {
    return 'AppError('
        'code: ${code.name}, '
        'operation: $operation, '
        'retryable: $retryable'
        ')';
  }
}

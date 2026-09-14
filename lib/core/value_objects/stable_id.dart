import '../errors/app_error.dart';
import '../errors/app_error_code.dart';
import '../result/app_result.dart';

/// An immutable, validated identifier for stable catalog references.
///
/// Valid identifiers match `^[a-z][a-z0-9_]*$`. Input is never normalized
/// automatically because changing an identifier could break references.
final class StableId {
  const StableId._(this.value);

  static final RegExp _pattern = RegExp(r'^[a-z][a-z0-9_]*$');

  final String value;

  static AppResult<StableId> create(String value) {
    final match = _pattern.matchAsPrefix(value);
    if (match == null || match.end != value.length) {
      return AppFailure<StableId>(
        AppError(
          code: AppErrorCode.invalidArgument,
          operation: 'stableId.create',
        ),
      );
    }

    return AppSuccess<StableId>(StableId._(value));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is StableId && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StableId($value)';
}

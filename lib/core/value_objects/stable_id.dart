import '../errors/app_error.dart';
import '../errors/app_error_code.dart';
import '../result/app_result.dart';

/// An immutable, validated identifier for stable catalog references.
///
/// A valid identifier:
/// - contains between 3 and 80 ASCII characters;
/// - starts with a lowercase ASCII letter;
/// - contains only lowercase ASCII letters, digits, and underscores.
///
/// Input is never trimmed or normalized automatically because changing an
/// identifier could break persistent references.
final class StableId {
  const StableId._(this.value);

  static const int minimumLength = 3;
  static const int maximumLength = 80;

  static final RegExp _pattern = RegExp(r'^[a-z][a-z0-9_]*$');

  final String value;

  static AppResult<StableId> create(String value) {
    if (value.length < minimumLength || value.length > maximumLength) {
      return _invalid();
    }

    final match = _pattern.matchAsPrefix(value);
    if (match == null || match.end != value.length) {
      return _invalid();
    }

    return AppSuccess<StableId>(StableId._(value));
  }

  static AppFailure<StableId> _invalid() {
    return AppFailure<StableId>(
      AppError(
        code: AppErrorCode.invalidArgument,
        operation: 'stableId.create',
      ),
    );
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

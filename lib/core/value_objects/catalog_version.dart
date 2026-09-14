import '../errors/app_error.dart';
import '../errors/app_error_code.dart';
import '../result/app_result.dart';

/// An immutable, validated, opaque catalog version.
///
/// This type intentionally does not implement semantic-version ordering.
/// Versions are matched using exact string equality.
final class CatalogVersion {
  const CatalogVersion._(this.value);

  static final RegExp _pattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]*$',
  );

  final String value;

  static AppResult<CatalogVersion> create(String value) {
    final match = _pattern.matchAsPrefix(value);
    if (match == null || match.end != value.length) {
      return AppFailure<CatalogVersion>(
        AppError(
          code: AppErrorCode.invalidArgument,
          operation: 'catalogVersion.create',
        ),
      );
    }

    return AppSuccess<CatalogVersion>(
      CatalogVersion._(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogVersion && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CatalogVersion($value)';
}

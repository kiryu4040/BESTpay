import '../errors/app_error.dart';
import '../errors/app_error_code.dart';
import '../result/app_result.dart';

/// An immutable, validated catalog version.
///
/// The stable format is `YYYY.MM.DD.REVISION`.
///
/// Examples:
/// - `2026.09.17.1`
/// - `2026.09.17.2`
///
/// The date must be a real Gregorian calendar date, and [revision] must be a
/// positive integer without leading zeroes.
final class CatalogVersion {
  const CatalogVersion._({
    required this.value,
    required this.year,
    required this.month,
    required this.day,
    required this.revision,
  });

  static final RegExp _pattern = RegExp(
    r'^([0-9]{4})\.(0[1-9]|1[0-2])\.'
    r'(0[1-9]|[12][0-9]|3[01])\.([1-9][0-9]*)$',
  );

  final String value;
  final int year;
  final int month;
  final int day;
  final int revision;

  static AppResult<CatalogVersion> create(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null || match.end != value.length) {
      return _invalid();
    }

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    final revision = int.tryParse(match.group(4)!);

    if (year == null ||
        month == null ||
        day == null ||
        revision == null ||
        revision < 1 ||
        !_isValidDate(year, month, day)) {
      return _invalid();
    }

    return AppSuccess<CatalogVersion>(
      CatalogVersion._(
        value: value,
        year: year,
        month: month,
        day: day,
        revision: revision,
      ),
    );
  }

  static bool _isValidDate(int year, int month, int day) {
    if (year < 1 || year > 9999) {
      return false;
    }

    final daysInMonth = switch (month) {
      2 => _isLeapYear(year) ? 29 : 28,
      4 || 6 || 9 || 11 => 30,
      _ => 31,
    };

    return day >= 1 && day <= daysInMonth;
  }

  static bool _isLeapYear(int year) {
    return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
  }

  static AppFailure<CatalogVersion> _invalid() {
    return AppFailure<CatalogVersion>(
      AppError(
        code: AppErrorCode.invalidArgument,
        operation: 'catalogVersion.create',
      ),
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

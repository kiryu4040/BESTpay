import '../errors/app_error.dart';
import '../errors/app_error_code.dart';
import '../result/app_result.dart';

/// An immutable Gregorian calendar date without a time or time zone.
final class CalculationDate implements Comparable<CalculationDate> {
  const CalculationDate._(
    this.year,
    this.month,
    this.day,
  );

  final int year;
  final int month;
  final int day;

  /// Creates a validated date.
  ///
  /// Years are limited to 1 through 9999 so the stable representation remains
  /// exactly YYYY-MM-DD.
  static AppResult<CalculationDate> create(
    int year,
    int month,
    int day,
  ) {
    return _createForOperation(
      year,
      month,
      day,
      'calculationDate.create',
    );
  }

  /// Creates a date from the UTC calendar components of [value].
  ///
  /// A local DateTime is rejected instead of being converted implicitly.
  static AppResult<CalculationDate> fromUtc(DateTime value) {
    if (!value.isUtc) {
      return _invalid('calculationDate.fromUtc');
    }

    return AppSuccess<CalculationDate>(
      CalculationDate._(
        value.year,
        value.month,
        value.day,
      ),
    );
  }

  /// Parses the stable YYYY-MM-DD representation.
  static AppResult<CalculationDate> parse(String value) {
    final match = RegExp(
      r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$',
    ).firstMatch(value);

    if (match == null) {
      return _invalid('calculationDate.parse');
    }

    return _createForOperation(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      'calculationDate.parse',
    );
  }

  DateTime toUtcDateTime() {
    return DateTime.utc(year, month, day);
  }

  @override
  int compareTo(CalculationDate other) {
    final yearComparison = year.compareTo(other.year);
    if (yearComparison != 0) {
      return yearComparison;
    }

    final monthComparison = month.compareTo(other.month);
    if (monthComparison != 0) {
      return monthComparison;
    }

    return day.compareTo(other.day);
  }

  bool operator <(CalculationDate other) => compareTo(other) < 0;

  bool operator <=(CalculationDate other) => compareTo(other) <= 0;

  bool operator >(CalculationDate other) => compareTo(other) > 0;

  bool operator >=(CalculationDate other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CalculationDate &&
            year == other.year &&
            month == other.month &&
            day == other.day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() {
    final yearText = year.toString().padLeft(4, '0');
    final monthText = month.toString().padLeft(2, '0');
    final dayText = day.toString().padLeft(2, '0');
    return '$yearText-$monthText-$dayText';
  }

  static AppResult<CalculationDate> _createForOperation(
    int year,
    int month,
    int day,
    String operation,
  ) {
    if (!_isValidDate(year, month, day)) {
      return _invalid(operation);
    }

    return AppSuccess<CalculationDate>(
      CalculationDate._(year, month, day),
    );
  }

  static bool _isValidDate(int year, int month, int day) {
    if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
      return false;
    }

    final daysInMonth = switch (month) {
      2 => _isLeapYear(year) ? 29 : 28,
      4 || 6 || 9 || 11 => 30,
      _ => 31,
    };

    return day <= daysInMonth;
  }

  static bool _isLeapYear(int year) {
    return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
  }

  static AppFailure<CalculationDate> _invalid(String operation) {
    return AppFailure<CalculationDate>(
      AppError(
        code: AppErrorCode.invalidArgument,
        operation: operation,
      ),
    );
  }
}

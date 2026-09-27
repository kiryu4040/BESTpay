import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/validity_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ValidityPeriod', () {
    test('an unbounded period contains every valid date', () {
      expect(
        ValidityPeriod.unbounded.contains(_date(1, 1, 1)),
        isTrue,
      );
      expect(
        ValidityPeriod.unbounded.contains(_date(9999, 12, 31)),
        isTrue,
      );
      expect(ValidityPeriod.unbounded.isEmpty, isFalse);
    });

    test('includes the start and excludes the end', () {
      final period = _period(
        ValidityPeriod.create(
          startsOn: _date(2026, 9, 1),
          endsBefore: _date(2026, 10, 1),
        ),
      );

      expect(period.contains(_date(2026, 8, 31)), isFalse);
      expect(period.contains(_date(2026, 9, 1)), isTrue);
      expect(period.contains(_date(2026, 9, 30)), isTrue);
      expect(period.contains(_date(2026, 10, 1)), isFalse);
    });

    test('supports a period with only a start boundary', () {
      final period = _period(
        ValidityPeriod.create(
          startsOn: _date(2026, 9, 1),
        ),
      );

      expect(period.contains(_date(2026, 8, 31)), isFalse);
      expect(period.contains(_date(2026, 9, 1)), isTrue);
      expect(period.contains(_date(9999, 12, 31)), isTrue);
    });

    test('supports a period with only an end boundary', () {
      final period = _period(
        ValidityPeriod.create(
          endsBefore: _date(2026, 9, 1),
        ),
      );

      expect(period.contains(_date(1, 1, 1)), isTrue);
      expect(period.contains(_date(2026, 8, 31)), isTrue);
      expect(period.contains(_date(2026, 9, 1)), isFalse);
    });

    test('allows equal boundaries as an empty period', () {
      final boundary = _date(2026, 9, 1);
      final period = _period(
        ValidityPeriod.create(
          startsOn: boundary,
          endsBefore: boundary,
        ),
      );

      expect(period.isEmpty, isTrue);
      expect(period.contains(_date(2026, 8, 31)), isFalse);
      expect(period.contains(boundary), isFalse);
      expect(period.contains(_date(2026, 9, 2)), isFalse);
    });

    test('rejects a start date after the end date', () {
      final error = _failure(
        ValidityPeriod.create(
          startsOn: _date(2026, 10, 1),
          endsBefore: _date(2026, 9, 1),
        ),
      );

      expect(error.code, AppErrorCode.invalidArgument);
      expect(error.operation, 'validityPeriod.create');
      expect(error.retryable, isFalse);
    });

    test('handles leap-day boundaries', () {
      final period = _period(
        ValidityPeriod.create(
          startsOn: _date(2028, 2, 29),
          endsBefore: _date(2028, 3, 1),
        ),
      );

      expect(period.contains(_date(2028, 2, 28)), isFalse);
      expect(period.contains(_date(2028, 2, 29)), isTrue);
      expect(period.contains(_date(2028, 3, 1)), isFalse);
    });

    test('uses boundaries for equality, hashCode, and debug text', () {
      final first = _period(
        ValidityPeriod.create(
          startsOn: _date(2026, 9, 1),
          endsBefore: _date(2026, 10, 1),
        ),
      );
      final second = _period(
        ValidityPeriod.create(
          startsOn: _date(2026, 9, 1),
          endsBefore: _date(2026, 10, 1),
        ),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first.toString(),
        'ValidityPeriod([2026-09-01, 2026-10-01))',
      );
    });
  });
}

CalculationDate _date(int year, int month, int day) {
  final result = CalculationDate.create(year, month, day);
  expect(result, isA<AppSuccess<CalculationDate>>());
  return (result as AppSuccess<CalculationDate>).value;
}

ValidityPeriod _period(AppResult<ValidityPeriod> result) {
  expect(result, isA<AppSuccess<ValidityPeriod>>());
  return (result as AppSuccess<ValidityPeriod>).value;
}

AppError _failure(AppResult<ValidityPeriod> result) {
  expect(result, isA<AppFailure<ValidityPeriod>>());
  return (result as AppFailure<ValidityPeriod>).error;
}

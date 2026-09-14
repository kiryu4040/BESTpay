import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalculationDate creation', () {
    test('creates a valid date and stable representation', () {
      final date = _success(CalculationDate.create(2026, 9, 14));

      expect(date.year, 2026);
      expect(date.month, 9);
      expect(date.day, 14);
      expect(date.toString(), '2026-09-14');
    });

    test('accepts a leap day in a leap year', () {
      final date = _success(CalculationDate.create(2028, 2, 29));

      expect(date.toString(), '2028-02-29');
    });

    test('rejects a leap day in a non-leap year', () {
      final error = _failure(CalculationDate.create(2026, 2, 29));

      expect(error.code, AppErrorCode.invalidArgument);
      expect(error.operation, 'calculationDate.create');
    });

    test('applies Gregorian century leap-year rules', () {
      final year2000 = _success(CalculationDate.create(2000, 2, 29));
      final year2100 = _failure(CalculationDate.create(2100, 2, 29));

      expect(year2000.toString(), '2000-02-29');
      expect(year2100.code, AppErrorCode.invalidArgument);
    });

    test('rejects out-of-range date components', () {
      final invalidValues = <AppResult<CalculationDate>>[
        CalculationDate.create(0, 1, 1),
        CalculationDate.create(10000, 1, 1),
        CalculationDate.create(2026, 0, 1),
        CalculationDate.create(2026, 13, 1),
        CalculationDate.create(2026, 1, 0),
        CalculationDate.create(2026, 4, 31),
      ];

      for (final result in invalidValues) {
        final error = _failure(result);
        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'calculationDate.create');
      }
    });
  });

  group('CalculationDate parsing and UTC conversion', () {
    test('parses the exact YYYY-MM-DD representation', () {
      final date = _success(CalculationDate.parse('2026-09-04'));

      expect(date.year, 2026);
      expect(date.month, 9);
      expect(date.day, 4);
      expect(date.toString(), '2026-09-04');
    });

    test('rejects malformed or impossible text dates', () {
      final invalidValues = <String>[
        '2026-9-04',
        '2026-09-4',
        '2026/09/04',
        ' 2026-09-04',
        '2026-09-04 ',
        '2026-09-04\n',
        '2026-02-29',
      ];

      for (final value in invalidValues) {
        final error = _failure(CalculationDate.parse(value));
        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'calculationDate.parse');
      }
    });

    test('uses UTC calendar components without retaining time', () {
      final instant = DateTime.utc(2026, 9, 14, 23, 59, 59);
      final date = _success(CalculationDate.fromUtc(instant));

      expect(date.toString(), '2026-09-14');
      expect(date.toUtcDateTime(), DateTime.utc(2026, 9, 14));
      expect(date.toUtcDateTime().isUtc, isTrue);
    });

    test('rejects a local DateTime instead of converting implicitly', () {
      final localDateTime = DateTime(2026, 9, 14);
      final error = _failure(
        CalculationDate.fromUtc(localDateTime),
      );

      expect(error.code, AppErrorCode.invalidArgument);
      expect(error.operation, 'calculationDate.fromUtc');
    });

    test('rejects a UTC date outside the stable four-digit year range', () {
      final error = _failure(
        CalculationDate.fromUtc(DateTime.utc(10000, 1, 1)),
      );

      expect(error.code, AppErrorCode.invalidArgument);
      expect(error.operation, 'calculationDate.fromUtc');
    });
  });

  group('CalculationDate comparison and equality', () {
    test('compares dates chronologically and uses value equality', () {
      final earlier = _success(CalculationDate.create(2026, 9, 13));
      final sameFirst = _success(CalculationDate.create(2026, 9, 14));
      final sameSecond = _success(CalculationDate.create(2026, 9, 14));
      final later = _success(CalculationDate.create(2027, 1, 1));

      expect(earlier < sameFirst, isTrue);
      expect(earlier <= earlier, isTrue);
      expect(later > sameFirst, isTrue);
      expect(later >= later, isTrue);
      expect(sameFirst, sameSecond);
      expect(sameFirst.hashCode, sameSecond.hashCode);
      expect(sameFirst.compareTo(later), lessThan(0));
    });
  });
}

CalculationDate _success(AppResult<CalculationDate> result) {
  expect(result, isA<AppSuccess<CalculationDate>>());
  return (result as AppSuccess<CalculationDate>).value;
}

AppError _failure(AppResult<CalculationDate> result) {
  expect(result, isA<AppFailure<CalculationDate>>());
  return (result as AppFailure<CalculationDate>).error;
}

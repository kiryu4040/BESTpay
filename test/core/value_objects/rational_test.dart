import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/rounding_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rational creation', () {
    test('normalizes fractions and keeps the denominator positive', () {
      final half = _success(Rational.create(2, 4));
      final negativeHalf = _success(Rational.create(1, -2));

      expect(half.numerator, 1);
      expect(half.denominator, 2);
      expect(negativeHalf.numerator, -1);
      expect(negativeHalf.denominator, 2);
    });

    test('normalizes zero to zero over one', () {
      final value = _success(Rational.create(0, -25));

      expect(value, Rational.zero);
      expect(value.numerator, 0);
      expect(value.denominator, 1);
    });

    test('rejects a zero denominator', () {
      final error = _failure(Rational.create(1, 0));

      expect(error.code, AppErrorCode.invalidArgument);
      expect(error.operation, 'rational.create');
      expect(error.retryable, isFalse);
    });

    test('creates an integer with denominator one', () {
      final value = Rational.fromInt(-12);

      expect(value.numerator, -12);
      expect(value.denominator, 1);
    });
  });

  group('Rational arithmetic', () {
    test('adds, subtracts, and multiplies exactly', () {
      final oneHalf = _success(Rational.create(1, 2));
      final oneThird = _success(Rational.create(1, 3));

      expect(oneHalf + oneThird, _success(Rational.create(5, 6)));
      expect(oneHalf - oneThird, _success(Rational.create(1, 6)));
      expect(oneHalf * oneThird, _success(Rational.create(1, 6)));
    });

    test('negates a value exactly', () {
      final value = _success(Rational.create(3, 7));

      expect(-value, _success(Rational.create(-3, 7)));
      expect(-(-value), value);
    });

    test('divides by a non-zero value exactly', () {
      final oneHalf = _success(Rational.create(1, 2));
      final threeQuarters = _success(Rational.create(3, 4));

      final result = oneHalf.divideBy(threeQuarters);

      expect(_success(result), _success(Rational.create(2, 3)));
    });

    test('rejects division by zero', () {
      final value = _success(Rational.create(1, 2));

      final error = _failure(value.divideBy(Rational.zero));

      expect(error.code, AppErrorCode.invalidArgument);
      expect(error.operation, 'rational.divide');
      expect(error.retryable, isFalse);
    });
  });

  group('Rational comparison and equality', () {
    test('compares values without converting to double', () {
      final oneThird = _success(Rational.create(1, 3));
      final oneHalf = _success(Rational.create(1, 2));
      final twoThirds = _success(Rational.create(2, 3));

      expect(oneThird < oneHalf, isTrue);
      expect(oneHalf <= oneHalf, isTrue);
      expect(twoThirds > oneHalf, isTrue);
      expect(twoThirds >= twoThirds, isTrue);
      expect(oneHalf.compareTo(twoThirds), lessThan(0));
    });

    test('uses normalized values for equality and hashCode', () {
      final first = _success(Rational.create(2, 4));
      final second = _success(Rational.create(-3, -6));

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), '1/2');
    });
  });

  group('Rational rounding', () {
    test('rounds positive fractions using every mode', () {
      final value = _success(Rational.create(7, 3));

      expect(value.round(RoundingMode.towardZero), 2);
      expect(value.round(RoundingMode.floor), 2);
      expect(value.round(RoundingMode.ceiling), 3);
      expect(value.round(RoundingMode.halfAwayFromZero), 2);
    });

    test('distinguishes floor from towardZero for negative fractions', () {
      final value = _success(Rational.create(-7, 3));

      expect(value.round(RoundingMode.towardZero), -2);
      expect(value.round(RoundingMode.floor), -3);
      expect(value.round(RoundingMode.ceiling), -2);
      expect(value.round(RoundingMode.halfAwayFromZero), -2);
    });

    test('rounds exact halves away from zero', () {
      final positive = _success(Rational.create(5, 2));
      final negative = _success(Rational.create(-5, 2));

      expect(positive.round(RoundingMode.halfAwayFromZero), 3);
      expect(negative.round(RoundingMode.halfAwayFromZero), -3);
    });

    test('leaves exact integers unchanged in every mode', () {
      final value = Rational.fromInt(-3);

      for (final mode in RoundingMode.values) {
        expect(value.round(mode), -3);
      }
    });
  });
}

Rational _success(AppResult<Rational> result) {
  expect(result, isA<AppSuccess<Rational>>());
  return (result as AppSuccess<Rational>).value;
}

AppError _failure(AppResult<Rational> result) {
  expect(result, isA<AppFailure<Rational>>());
  return (result as AppFailure<Rational>).error;
}

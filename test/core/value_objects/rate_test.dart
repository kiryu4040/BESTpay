import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/rate.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rate creation', () {
    test('provides exact zero and one constants', () {
      expect(Rate.zero.ratio, Rational.zero);
      expect(Rate.zero.isZero, isTrue);
      expect(Rate.one.ratio, Rational.one);
      expect(Rate.one.isZero, isFalse);
    });

    test('represents one percent and half a percent exactly', () {
      final onePercent = _rateSuccess(Rate.create(1, 100));
      final halfPercent = _rateSuccess(Rate.create(5, 1000));

      expect(onePercent.ratio, _rationalSuccess(Rational.create(1, 100)));
      expect(halfPercent.ratio, _rationalSuccess(Rational.create(1, 200)));
    });

    test('normalizes equivalent rates', () {
      final first = _rateSuccess(Rate.create(2, 200));
      final second = _rateSuccess(Rate.create(1, 100));

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('rejects a zero denominator', () {
      final error = _rateFailure(Rate.create(1, 0));

      expect(error.code, AppErrorCode.invalidArgument);
      expect(error.operation, 'rate.create');
      expect(error.retryable, isFalse);
    });

    test('rejects negative rates', () {
      final negativeNumerator = _rateFailure(Rate.create(-1, 100));
      final negativeDenominator = _rateFailure(Rate.create(1, -100));

      expect(negativeNumerator.code, AppErrorCode.invalidArgument);
      expect(negativeNumerator.operation, 'rate.create');
      expect(negativeDenominator.code, AppErrorCode.invalidArgument);
      expect(negativeDenominator.operation, 'rate.create');
    });

    test('allows rates greater than one hundred percent', () {
      final rate = _rateSuccess(Rate.create(3, 2));

      expect(rate.ratio, _rationalSuccess(Rational.create(3, 2)));
      expect(rate > Rate.one, isTrue);
    });

    test('creates a rate from a non-negative rational value', () {
      final ratio = _rationalSuccess(Rational.create(3, 200));
      final rate = _rateSuccess(Rate.fromRational(ratio));

      expect(rate.ratio, ratio);
    });

    test('rejects a negative rational value', () {
      final ratio = _rationalSuccess(Rational.create(-1, 10));
      final error = _rateFailure(Rate.fromRational(ratio));

      expect(error.code, AppErrorCode.invalidArgument);
      expect(error.operation, 'rate.create');
    });
  });

  group('Rate operations', () {
    test('adds and compares rates exactly', () {
      final onePercent = _rateSuccess(Rate.create(1, 100));
      final halfPercent = _rateSuccess(Rate.create(1, 200));
      final expected = _rateSuccess(Rate.create(3, 200));

      final sum = onePercent + halfPercent;

      expect(sum, expected);
      expect(halfPercent < onePercent, isTrue);
      expect(onePercent <= onePercent, isTrue);
      expect(sum > onePercent, isTrue);
      expect(sum >= expected, isTrue);
      expect(sum.toString(), 'Rate(3/200)');
      expect(sum.toString(), isNot(contains('%')));
    });
  });
}

Rate _rateSuccess(AppResult<Rate> result) {
  expect(result, isA<AppSuccess<Rate>>());
  return (result as AppSuccess<Rate>).value;
}

AppError _rateFailure(AppResult<Rate> result) {
  expect(result, isA<AppFailure<Rate>>());
  return (result as AppFailure<Rate>).error;
}

Rational _rationalSuccess(AppResult<Rational> result) {
  expect(result, isA<AppSuccess<Rational>>());
  return (result as AppSuccess<Rational>).value;
}

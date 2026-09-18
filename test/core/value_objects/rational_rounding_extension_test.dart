import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/rounding_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rational extended rounding modes', () {
    test('halfToEven rounds positive halves to an even integer', () {
      final fiveHalves = _success(Rational.create(5, 2));
      final sevenHalves = _success(Rational.create(7, 2));

      expect(fiveHalves.round(RoundingMode.halfToEven), 2);
      expect(sevenHalves.round(RoundingMode.halfToEven), 4);
    });

    test('halfToEven rounds negative halves to an even integer', () {
      final negativeFiveHalves = _success(Rational.create(-5, 2));
      final negativeSevenHalves = _success(Rational.create(-7, 2));

      expect(negativeFiveHalves.round(RoundingMode.halfToEven), -2);
      expect(negativeSevenHalves.round(RoundingMode.halfToEven), -4);
    });

    test('halfToEven handles values below and above the midpoint', () {
      final belowPositiveHalf = _success(Rational.create(249, 100));
      final abovePositiveHalf = _success(Rational.create(251, 100));
      final belowNegativeHalf = _success(Rational.create(-249, 100));
      final aboveNegativeHalf = _success(Rational.create(-251, 100));

      expect(belowPositiveHalf.round(RoundingMode.halfToEven), 2);
      expect(abovePositiveHalf.round(RoundingMode.halfToEven), 3);
      expect(belowNegativeHalf.round(RoundingMode.halfToEven), -2);
      expect(aboveNegativeHalf.round(RoundingMode.halfToEven), -3);
    });

    test('exact accepts integer rational values', () {
      final positive = Rational.fromInt(3);
      const zero = Rational.zero;
      final negative = Rational.fromInt(-3);

      expect(positive.round(RoundingMode.exact), 3);
      expect(zero.round(RoundingMode.exact), 0);
      expect(negative.round(RoundingMode.exact), -3);
    });

    test('exact rejects positive and negative fractions', () {
      final positive = _success(Rational.create(7, 3));
      final negative = _success(Rational.create(-7, 3));

      expect(
        () => positive.round(RoundingMode.exact),
        throwsStateError,
      );
      expect(
        () => negative.round(RoundingMode.exact),
        throwsStateError,
      );
    });
  });
}

Rational _success(AppResult<Rational> result) {
  expect(result, isA<AppSuccess<Rational>>());
  return (result as AppSuccess<Rational>).value;
}

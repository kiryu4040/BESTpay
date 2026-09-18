import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/rounding_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoundingMode', () {
    test('has stable names instead of relying on enum indexes', () {
      expect(RoundingMode.towardZero.name, 'towardZero');
      expect(RoundingMode.floor.name, 'floor');
      expect(RoundingMode.ceiling.name, 'ceiling');
      expect(RoundingMode.halfAwayFromZero.name, 'halfAwayFromZero');
      expect(RoundingMode.halfToEven.name, 'halfToEven');
      expect(RoundingMode.exact.name, 'exact');
    });
  });

  group('MicrosYen', () {
    test('stores positive, zero, and negative micro-yen values', () {
      const positive = MicrosYen(1500000);
      const zero = MicrosYen.zero;
      const negative = MicrosYen(-250000);

      expect(positive.micros, 1500000);
      expect(positive.isZero, isFalse);
      expect(positive.isNegative, isFalse);

      expect(zero.micros, 0);
      expect(zero.isZero, isTrue);
      expect(zero.isNegative, isFalse);

      expect(negative.micros, -250000);
      expect(negative.isZero, isFalse);
      expect(negative.isNegative, isTrue);
    });

    test('converts whole yen to micros exactly', () {
      final positive = MicrosYen.fromMoneyYen(const MoneyYen(123));
      final negative = MicrosYen.fromMoneyYen(const MoneyYen(-5));

      expect(positive, const MicrosYen(123000000));
      expect(negative, const MicrosYen(-5000000));
    });

    test('adds and subtracts exact micro-yen values', () {
      const first = MicrosYen(1250000);
      const second = MicrosYen(500000);

      expect(first + second, const MicrosYen(1750000));
      expect(first - second, const MicrosYen(750000));
      expect(second - first, const MicrosYen(-750000));
    });

    test('negates and multiplies by an integer', () {
      const value = MicrosYen(250000);

      expect(-value, const MicrosYen(-250000));
      expect(-(-value), value);
      expect(value * 4, const MicrosYen(1000000));
      expect(value * -2, const MicrosYen(-500000));
    });

    test('compares values and uses value equality', () {
      const smaller = MicrosYen(-1);
      const middle = MicrosYen.zero;
      const larger = MicrosYen(1);
      const sameLarger = MicrosYen(1);

      expect(smaller < middle, isTrue);
      expect(smaller <= smaller, isTrue);
      expect(larger > middle, isTrue);
      expect(larger >= sameLarger, isTrue);
      expect(larger, sameLarger);
      expect(larger.hashCode, sameLarger.hashCode);
      expect(larger.toString(), 'MicrosYen(1)');
    });

    test('rounds positive fractional yen using directional modes', () {
      const value = MicrosYen(2400000);

      expect(value.toMoneyYen(RoundingMode.towardZero), const MoneyYen(2));
      expect(value.toMoneyYen(RoundingMode.floor), const MoneyYen(2));
      expect(value.toMoneyYen(RoundingMode.ceiling), const MoneyYen(3));
    });

    test('rounds negative fractional yen using directional modes', () {
      const value = MicrosYen(-2400000);

      expect(value.toMoneyYen(RoundingMode.towardZero), const MoneyYen(-2));
      expect(value.toMoneyYen(RoundingMode.floor), const MoneyYen(-3));
      expect(value.toMoneyYen(RoundingMode.ceiling), const MoneyYen(-2));
    });

    test('halfAwayFromZero rounds exact halves away from zero', () {
      const positiveHalf = MicrosYen(2500000);
      const negativeHalf = MicrosYen(-2500000);
      const belowPositiveHalf = MicrosYen(2499999);
      const belowNegativeHalf = MicrosYen(-2499999);

      expect(
        positiveHalf.toMoneyYen(RoundingMode.halfAwayFromZero),
        const MoneyYen(3),
      );
      expect(
        negativeHalf.toMoneyYen(RoundingMode.halfAwayFromZero),
        const MoneyYen(-3),
      );
      expect(
        belowPositiveHalf.toMoneyYen(RoundingMode.halfAwayFromZero),
        const MoneyYen(2),
      );
      expect(
        belowNegativeHalf.toMoneyYen(RoundingMode.halfAwayFromZero),
        const MoneyYen(-2),
      );
    });

    test('halfToEven rounds positive exact halves to an even value', () {
      const halfAboveEven = MicrosYen(2500000);
      const halfAboveOdd = MicrosYen(3500000);

      expect(
        halfAboveEven.toMoneyYen(RoundingMode.halfToEven),
        const MoneyYen(2),
      );
      expect(
        halfAboveOdd.toMoneyYen(RoundingMode.halfToEven),
        const MoneyYen(4),
      );
    });

    test('halfToEven rounds negative exact halves to an even value', () {
      const halfBelowEven = MicrosYen(-2500000);
      const halfBelowOdd = MicrosYen(-3500000);

      expect(
        halfBelowEven.toMoneyYen(RoundingMode.halfToEven),
        const MoneyYen(-2),
      );
      expect(
        halfBelowOdd.toMoneyYen(RoundingMode.halfToEven),
        const MoneyYen(-4),
      );
    });

    test('halfToEven rounds values below and above the midpoint', () {
      const belowPositiveHalf = MicrosYen(2499999);
      const abovePositiveHalf = MicrosYen(2500001);
      const belowNegativeHalf = MicrosYen(-2499999);
      const aboveNegativeHalf = MicrosYen(-2500001);

      expect(
        belowPositiveHalf.toMoneyYen(RoundingMode.halfToEven),
        const MoneyYen(2),
      );
      expect(
        abovePositiveHalf.toMoneyYen(RoundingMode.halfToEven),
        const MoneyYen(3),
      );
      expect(
        belowNegativeHalf.toMoneyYen(RoundingMode.halfToEven),
        const MoneyYen(-2),
      );
      expect(
        aboveNegativeHalf.toMoneyYen(RoundingMode.halfToEven),
        const MoneyYen(-3),
      );
    });

    test('exact accepts whole yen for positive, zero, and negative values', () {
      const positive = MicrosYen(3000000);
      const zero = MicrosYen.zero;
      const negative = MicrosYen(-3000000);

      expect(positive.toMoneyYen(RoundingMode.exact), const MoneyYen(3));
      expect(zero.toMoneyYen(RoundingMode.exact), MoneyYen.zero);
      expect(negative.toMoneyYen(RoundingMode.exact), const MoneyYen(-3));
    });

    test('exact rejects positive and negative fractional yen', () {
      const positive = MicrosYen(3000001);
      const negative = MicrosYen(-3000001);

      expect(() => positive.toMoneyYen(RoundingMode.exact), throwsStateError);
      expect(() => negative.toMoneyYen(RoundingMode.exact), throwsStateError);
    });

    test('all rounding modes preserve whole yen', () {
      const positive = MicrosYen(3000000);
      const negative = MicrosYen(-3000000);

      for (final mode in RoundingMode.values) {
        expect(positive.toMoneyYen(mode), const MoneyYen(3));
        expect(negative.toMoneyYen(mode), const MoneyYen(-3));
      }
    });
  });
}

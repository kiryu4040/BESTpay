import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/rounding_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    test('rounds positive fractional yen using every mode', () {
      const value = MicrosYen(2400000);

      expect(
        value.toMoneyYen(RoundingMode.towardZero),
        const MoneyYen(2),
      );
      expect(
        value.toMoneyYen(RoundingMode.floor),
        const MoneyYen(2),
      );
      expect(
        value.toMoneyYen(RoundingMode.ceiling),
        const MoneyYen(3),
      );
      expect(
        value.toMoneyYen(RoundingMode.halfAwayFromZero),
        const MoneyYen(2),
      );
    });

    test('rounds negative fractional yen using every mode', () {
      const value = MicrosYen(-2400000);

      expect(
        value.toMoneyYen(RoundingMode.towardZero),
        const MoneyYen(-2),
      );
      expect(
        value.toMoneyYen(RoundingMode.floor),
        const MoneyYen(-3),
      );
      expect(
        value.toMoneyYen(RoundingMode.ceiling),
        const MoneyYen(-2),
      );
      expect(
        value.toMoneyYen(RoundingMode.halfAwayFromZero),
        const MoneyYen(-2),
      );
    });

    test('rounds exact halves away from zero and preserves whole yen', () {
      const positiveHalf = MicrosYen(2500000);
      const negativeHalf = MicrosYen(-2500000);
      const whole = MicrosYen(-3000000);

      expect(
        positiveHalf.toMoneyYen(RoundingMode.halfAwayFromZero),
        const MoneyYen(3),
      );
      expect(
        negativeHalf.toMoneyYen(RoundingMode.halfAwayFromZero),
        const MoneyYen(-3),
      );

      for (final mode in RoundingMode.values) {
        expect(whole.toMoneyYen(mode), const MoneyYen(-3));
      }
    });
  });
}

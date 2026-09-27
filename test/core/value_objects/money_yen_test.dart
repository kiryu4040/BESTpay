import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyYen', () {
    test('stores positive, zero, and negative whole-yen values', () {
      const positive = MoneyYen(1500);
      const zero = MoneyYen.zero;
      const negative = MoneyYen(-250);

      expect(positive.yen, 1500);
      expect(positive.isZero, isFalse);
      expect(positive.isNegative, isFalse);

      expect(zero.yen, 0);
      expect(zero.isZero, isTrue);
      expect(zero.isNegative, isFalse);

      expect(negative.yen, -250);
      expect(negative.isZero, isFalse);
      expect(negative.isNegative, isTrue);
    });

    test('adds and subtracts exact whole-yen values', () {
      const first = MoneyYen(1200);
      const second = MoneyYen(450);

      expect(first + second, const MoneyYen(1650));
      expect(first - second, const MoneyYen(750));
      expect(second - first, const MoneyYen(-750));
    });

    test('negates a value', () {
      const value = MoneyYen(500);

      expect(-value, const MoneyYen(-500));
      expect(-(-value), value);
      expect(-MoneyYen.zero, MoneyYen.zero);
    });

    test('multiplies by an integer', () {
      const value = MoneyYen(125);

      expect(value * 4, const MoneyYen(500));
      expect(value * 0, MoneyYen.zero);
      expect(value * -2, const MoneyYen(-250));
    });

    test('compares values', () {
      const smaller = MoneyYen(-1);
      const middle = MoneyYen.zero;
      const larger = MoneyYen(1);

      expect(smaller < middle, isTrue);
      expect(smaller <= smaller, isTrue);
      expect(larger > middle, isTrue);
      expect(larger >= larger, isTrue);
      expect(middle.compareTo(larger), lessThan(0));
    });

    test('uses the yen value for equality and hashCode', () {
      const first = MoneyYen(1000);
      const second = MoneyYen(1000);
      const different = MoneyYen(1001);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('toString remains a debug representation', () {
      const value = MoneyYen(1234);

      expect(value.toString(), 'MoneyYen(1234)');
      expect(value.toString(), isNot(contains('¥')));
      expect(value.toString(), isNot(contains(',')));
    });
  });
}

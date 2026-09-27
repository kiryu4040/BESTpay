import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PointAmount', () {
    test('stores positive, zero, and negative whole-point values', () {
      const positive = PointAmount(1500);
      const zero = PointAmount.zero;
      const negative = PointAmount(-250);

      expect(positive.points, 1500);
      expect(positive.isZero, isFalse);
      expect(positive.isNegative, isFalse);

      expect(zero.points, 0);
      expect(zero.isZero, isTrue);
      expect(zero.isNegative, isFalse);

      expect(negative.points, -250);
      expect(negative.isZero, isFalse);
      expect(negative.isNegative, isTrue);
    });

    test('adds and subtracts exact whole-point values', () {
      const first = PointAmount(1200);
      const second = PointAmount(450);

      expect(first + second, const PointAmount(1650));
      expect(first - second, const PointAmount(750));
      expect(second - first, const PointAmount(-750));
    });

    test('negates a value', () {
      const value = PointAmount(500);

      expect(-value, const PointAmount(-500));
      expect(-(-value), value);
      expect(-PointAmount.zero, PointAmount.zero);
    });

    test('multiplies by an integer', () {
      const value = PointAmount(125);

      expect(value * 4, const PointAmount(500));
      expect(value * 0, PointAmount.zero);
      expect(value * -2, const PointAmount(-250));
    });

    test('compares values', () {
      const smaller = PointAmount(-1);
      const middle = PointAmount.zero;
      const larger = PointAmount(1);

      expect(smaller < middle, isTrue);
      expect(smaller <= smaller, isTrue);
      expect(larger > middle, isTrue);
      expect(larger >= larger, isTrue);
      expect(middle.compareTo(larger), lessThan(0));
    });

    test('uses the point value for equality and hashCode', () {
      const first = PointAmount(1000);
      const second = PointAmount(1000);
      const different = PointAmount(1001);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('toString remains a debug representation', () {
      const value = PointAmount(1234);

      expect(value.toString(), 'PointAmount(1234)');
      expect(value.toString(), isNot(contains('pt')));
      expect(value.toString(), isNot(contains(',')));
    });
  });
}

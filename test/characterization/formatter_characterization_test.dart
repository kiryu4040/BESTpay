import 'package:bestpay/utils/formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Yen formatter legacy characterization', () {
    test('adds the yen symbol and thousands separators', () {
      expect(Fmt.yen(1234567), '¥1,234,567');
    });

    test('rounds a decimal value before displaying yen', () {
      expect(Fmt.yen(1234.4), '¥1,234');
      expect(Fmt.yen(1234.5), '¥1,235');
    });

    test('currently places the yen symbol before a negative sign', () {
      expect(Fmt.yen(-1234.5), '¥-1,235');
    });

    test('yenSimple omits the yen symbol', () {
      expect(Fmt.yenSimple(1234567), '1,234,567');
      expect(Fmt.yenSimple(1234.5), '1,235');
    });
  });

  group('Percentage formatter legacy characterization', () {
    test('pct always displays one decimal place', () {
      expect(Fmt.pct(0), '0.0%');
      expect(Fmt.pct(1), '1.0%');
      expect(Fmt.pct(12.5), '12.5%');
    });

    test('pct rounds to one decimal place', () {
      expect(Fmt.pct(1.24), '1.2%');
      expect(Fmt.pct(1.26), '1.3%');
    });

    test('pctShort omits decimals for whole numbers', () {
      expect(Fmt.pctShort(0), '0%');
      expect(Fmt.pctShort(1), '1%');
      expect(Fmt.pctShort(20), '20%');
    });

    test('pctShort displays one decimal for non-whole numbers', () {
      expect(Fmt.pctShort(0.5), '0.5%');
      expect(Fmt.pctShort(1.24), '1.2%');
      expect(Fmt.pctShort(1.26), '1.3%');
    });
  });
}

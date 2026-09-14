import 'package:bestpay/core/time/clock.dart';
import 'package:bestpay/core/time/system_clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixed_clock.dart';

void main() {
  group('SystemClock', () {
    test('implements Clock and returns the current UTC time', () {
      final before = DateTime.now().toUtc();
      const Clock clock = SystemClock();

      final actual = clock.nowUtc();
      final after = DateTime.now().toUtc();

      expect(actual.isUtc, isTrue);
      expect(actual.isBefore(before), isFalse);
      expect(actual.isAfter(after), isFalse);
    });
  });

  group('FixedClock', () {
    test('always returns the configured UTC instant', () {
      final instant = DateTime.utc(2026, 9, 14, 3, 0);
      final clock = FixedClock(instant);

      expect(clock.nowUtc(), instant);
      expect(clock.nowUtc(), instant);
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('normalizes a non-UTC DateTime to UTC', () {
      final localTime = DateTime(2026, 9, 14, 12, 0);
      final clock = FixedClock(localTime);

      expect(clock.nowUtc(), localTime.toUtc());
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('supports the end of a year', () {
      final instant = DateTime.utc(2026, 12, 31, 23, 59, 59);
      final clock = FixedClock(instant);

      expect(clock.nowUtc(), instant);
    });

    test('supports a leap day', () {
      final instant = DateTime.utc(2028, 2, 29);
      final clock = FixedClock(instant);

      expect(clock.nowUtc(), instant);
    });

    test('preserves the UTC instant at the Japan date boundary', () {
      final japanMidnight = DateTime.parse('2026-09-14T00:00:00+09:00');
      final expectedUtc = DateTime.utc(2026, 9, 13, 15);
      final clock = FixedClock(japanMidnight);

      expect(clock.nowUtc(), expectedUtc);
      expect(clock.nowUtc().isUtc, isTrue);
    });
  });
}

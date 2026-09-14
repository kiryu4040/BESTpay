import 'money_yen.dart';
import 'rounding_mode.dart';

/// An immutable amount represented in millionths of one Japanese yen.
///
/// This type is for exact intermediate calculations and is not intended for
/// direct user-interface formatting.
final class MicrosYen implements Comparable<MicrosYen> {
  const MicrosYen(this.micros);

  static const int microsPerYen = 1000000;
  static const MicrosYen zero = MicrosYen(0);

  final int micros;

  static MicrosYen fromMoneyYen(MoneyYen money) {
    return MicrosYen(money.yen * microsPerYen);
  }

  bool get isZero => micros == 0;

  bool get isNegative => micros < 0;

  MicrosYen operator -() => MicrosYen(-micros);

  MicrosYen operator +(MicrosYen other) {
    return MicrosYen(micros + other.micros);
  }

  MicrosYen operator -(MicrosYen other) {
    return MicrosYen(micros - other.micros);
  }

  MicrosYen operator *(int multiplier) {
    return MicrosYen(micros * multiplier);
  }

  /// Converts this value to whole yen using an explicit rounding policy.
  MoneyYen toMoneyYen(RoundingMode mode) {
    final quotient = micros ~/ microsPerYen;
    final remainder = micros.remainder(microsPerYen);

    if (remainder == 0) {
      return MoneyYen(quotient);
    }

    final rounded = switch (mode) {
      RoundingMode.towardZero => quotient,
      RoundingMode.floor => remainder < 0 ? quotient - 1 : quotient,
      RoundingMode.ceiling => remainder > 0 ? quotient + 1 : quotient,
      RoundingMode.halfAwayFromZero =>
        remainder.abs() * 2 >= microsPerYen ? quotient + micros.sign : quotient,
    };

    return MoneyYen(rounded);
  }

  @override
  int compareTo(MicrosYen other) {
    return micros.compareTo(other.micros);
  }

  bool operator <(MicrosYen other) => compareTo(other) < 0;

  bool operator <=(MicrosYen other) => compareTo(other) <= 0;

  bool operator >(MicrosYen other) => compareTo(other) > 0;

  bool operator >=(MicrosYen other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MicrosYen && micros == other.micros;
  }

  @override
  int get hashCode => micros.hashCode;

  @override
  String toString() => 'MicrosYen($micros)';
}

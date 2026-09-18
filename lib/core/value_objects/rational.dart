import '../errors/app_error.dart';
import '../errors/app_error_code.dart';
import '../result/app_result.dart';
import 'rounding_mode.dart';

/// An immutable, normalized rational number.
///
/// The denominator is always positive, and the numerator and denominator are
/// always reduced by their greatest common divisor.
final class Rational implements Comparable<Rational> {
  const Rational._(this.numerator, this.denominator);

  static const Rational zero = Rational._(0, 1);
  static const Rational one = Rational._(1, 1);

  final int numerator;
  final int denominator;

  /// Creates a normalized rational value.
  ///
  /// A zero denominator is returned as a structured failure.
  static AppResult<Rational> create(int numerator, int denominator) {
    if (denominator == 0) {
      return AppFailure<Rational>(
        AppError(
          code: AppErrorCode.invalidArgument,
          operation: 'rational.create',
        ),
      );
    }

    return AppSuccess<Rational>(
      _normalized(numerator, denominator),
    );
  }

  /// Creates a rational value whose denominator is one.
  static Rational fromInt(int value) {
    return Rational._(value, 1);
  }

  bool get isZero => numerator == 0;

  bool get isNegative => numerator < 0;

  Rational operator -() {
    return Rational._(-numerator, denominator);
  }

  Rational operator +(Rational other) {
    return _normalized(
      numerator * other.denominator + other.numerator * denominator,
      denominator * other.denominator,
    );
  }

  Rational operator -(Rational other) {
    return this + (-other);
  }

  Rational operator *(Rational other) {
    return _normalized(
      numerator * other.numerator,
      denominator * other.denominator,
    );
  }

  /// Divides this value by [other].
  ///
  /// Division by zero is returned as a structured failure.
  AppResult<Rational> divideBy(Rational other) {
    if (other.isZero) {
      return AppFailure<Rational>(
        AppError(
          code: AppErrorCode.invalidArgument,
          operation: 'rational.divide',
        ),
      );
    }

    return AppSuccess<Rational>(
      _normalized(
        numerator * other.denominator,
        denominator * other.numerator,
      ),
    );
  }

  /// Converts this exact value to an integer using [mode].
  int round(RoundingMode mode) {
    final quotient = numerator ~/ denominator;
    final remainder = numerator.remainder(denominator);

    if (remainder == 0) {
      return quotient;
    }

    return switch (mode) {
      RoundingMode.towardZero => quotient,
      RoundingMode.floor => remainder < 0 ? quotient - 1 : quotient,
      RoundingMode.ceiling => remainder > 0 ? quotient + 1 : quotient,
      RoundingMode.halfAwayFromZero => remainder.abs() * 2 >= denominator
          ? quotient + numerator.sign
          : quotient,
      RoundingMode.halfToEven => _roundHalfToEven(
          quotient: quotient,
          remainder: remainder,
          denominator: denominator,
        ),
      RoundingMode.exact => throw StateError(
          'Cannot round a non-integer rational value in exact mode.',
        ),
    };
  }

  static int _roundHalfToEven({
    required int quotient,
    required int remainder,
    required int denominator,
  }) {
    final doubledAbsoluteRemainder = remainder.abs() * 2;

    if (doubledAbsoluteRemainder < denominator) {
      return quotient;
    }

    if (doubledAbsoluteRemainder > denominator) {
      return quotient + remainder.sign;
    }

    return quotient.isEven ? quotient : quotient + remainder.sign;
  }

  @override
  int compareTo(Rational other) {
    final left = numerator * other.denominator;
    final right = other.numerator * denominator;
    return left.compareTo(right);
  }

  bool operator <(Rational other) => compareTo(other) < 0;

  bool operator <=(Rational other) => compareTo(other) <= 0;

  bool operator >(Rational other) => compareTo(other) > 0;

  bool operator >=(Rational other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Rational &&
            numerator == other.numerator &&
            denominator == other.denominator;
  }

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => '$numerator/$denominator';

  static Rational _normalized(int numerator, int denominator) {
    assert(denominator != 0);

    if (numerator == 0) {
      return zero;
    }

    final sign = denominator < 0 ? -1 : 1;
    final signedNumerator = numerator * sign;
    final positiveDenominator = denominator.abs();
    final divisor = _greatestCommonDivisor(
      signedNumerator.abs(),
      positiveDenominator,
    );

    return Rational._(
      signedNumerator ~/ divisor,
      positiveDenominator ~/ divisor,
    );
  }

  static int _greatestCommonDivisor(int left, int right) {
    var a = left;
    var b = right;

    while (b != 0) {
      final remainder = a % b;
      a = b;
      b = remainder;
    }

    return a;
  }
}

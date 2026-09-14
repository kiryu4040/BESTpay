import '../errors/app_error.dart';
import '../errors/app_error_code.dart';
import '../result/app_result.dart';
import 'rational.dart';

/// An immutable, exact, non-negative rate.
///
/// A rate is stored as a normalized [Rational]. Values greater than one are
/// allowed because some reward campaigns may exceed 100 percent.
final class Rate implements Comparable<Rate> {
  const Rate._(this.ratio);

  static const Rate zero = Rate._(Rational.zero);
  static const Rate one = Rate._(Rational.one);

  final Rational ratio;

  /// Creates a rate from an exact numerator and denominator.
  static AppResult<Rate> create(int numerator, int denominator) {
    final rationalResult = Rational.create(numerator, denominator);

    return rationalResult.fold<AppResult<Rate>>(
      onSuccess: fromRational,
      onFailure: (_) => _invalidRate(),
    );
  }

  /// Creates a rate from an existing rational value.
  static AppResult<Rate> fromRational(Rational ratio) {
    if (ratio.isNegative) {
      return _invalidRate();
    }

    return AppSuccess<Rate>(Rate._(ratio));
  }

  bool get isZero => ratio.isZero;

  Rate operator +(Rate other) {
    return Rate._(ratio + other.ratio);
  }

  @override
  int compareTo(Rate other) {
    return ratio.compareTo(other.ratio);
  }

  bool operator <(Rate other) => compareTo(other) < 0;

  bool operator <=(Rate other) => compareTo(other) <= 0;

  bool operator >(Rate other) => compareTo(other) > 0;

  bool operator >=(Rate other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is Rate && ratio == other.ratio;
  }

  @override
  int get hashCode => ratio.hashCode;

  @override
  String toString() => 'Rate($ratio)';

  static AppFailure<Rate> _invalidRate() {
    return AppFailure<Rate>(
      AppError(
        code: AppErrorCode.invalidArgument,
        operation: 'rate.create',
      ),
    );
  }
}

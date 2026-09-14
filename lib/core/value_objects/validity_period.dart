import '../errors/app_error.dart';
import '../errors/app_error_code.dart';
import '../result/app_result.dart';
import 'calculation_date.dart';

/// An immutable half-open date period: [startsOn, endsBefore).
///
/// The start is inclusive and the end is exclusive. Either boundary may be
/// absent. Equal boundaries represent an empty period.
final class ValidityPeriod {
  const ValidityPeriod._(
    this.startsOn,
    this.endsBefore,
  );

  static const ValidityPeriod unbounded = ValidityPeriod._(null, null);

  final CalculationDate? startsOn;
  final CalculationDate? endsBefore;

  static AppResult<ValidityPeriod> create({
    CalculationDate? startsOn,
    CalculationDate? endsBefore,
  }) {
    if (startsOn != null && endsBefore != null && startsOn > endsBefore) {
      return AppFailure<ValidityPeriod>(
        AppError(
          code: AppErrorCode.invalidArgument,
          operation: 'validityPeriod.create',
        ),
      );
    }

    if (startsOn == null && endsBefore == null) {
      return const AppSuccess<ValidityPeriod>(unbounded);
    }

    return AppSuccess<ValidityPeriod>(
      ValidityPeriod._(startsOn, endsBefore),
    );
  }

  bool get isEmpty {
    return startsOn != null && endsBefore != null && startsOn == endsBefore;
  }

  bool contains(CalculationDate date) {
    if (startsOn != null && date < startsOn!) {
      return false;
    }

    if (endsBefore != null && date >= endsBefore!) {
      return false;
    }

    return true;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ValidityPeriod &&
            startsOn == other.startsOn &&
            endsBefore == other.endsBefore;
  }

  @override
  int get hashCode => Object.hash(startsOn, endsBefore);

  @override
  String toString() {
    final startText = startsOn?.toString() ?? '-infinity';
    final endText = endsBefore?.toString() ?? 'infinity';
    return 'ValidityPeriod([$startText, $endText))';
  }
}

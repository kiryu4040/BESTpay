import 'package:bestpay/core/value_objects/money_yen.dart';

/// Read-only period values required to evaluate one threshold bonus.
///
/// Persistence and period mutation belong to PR-09. PR-08 only consumes this
/// immutable snapshot.
final class ThresholdPeriodSnapshot {
  const ThresholdPeriodSnapshot._({
    required this.periodSpendBefore,
    required this.awardsConsumed,
  });

  /// Creates a snapshot with runtime validation at the public boundary.
  factory ThresholdPeriodSnapshot.validated({
    required MoneyYen periodSpendBefore,
    required int awardsConsumed,
  }) {
    if (periodSpendBefore.isNegative) {
      throw ArgumentError.value(
        periodSpendBefore,
        'periodSpendBefore',
        'Period spend must not be negative.',
      );
    }

    if (awardsConsumed < 0) {
      throw ArgumentError.value(
        awardsConsumed,
        'awardsConsumed',
        'Consumed award count must not be negative.',
      );
    }

    return ThresholdPeriodSnapshot._(
      periodSpendBefore: periodSpendBefore,
      awardsConsumed: awardsConsumed,
    );
  }

  final MoneyYen periodSpendBefore;
  final int awardsConsumed;
}

import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';

/// Confidence assigned to externally supplied period aggregation data.
enum PeriodDataConfidence {
  exact,
  userEntered,
  estimated,
  unknown,
}

/// Immutable period state supplied to reward-rule evaluation.
///
/// The snapshot records values immediately before and after the current
/// transaction. [currentIncrement] is the difference between [pointsAfter] and
/// [pointsBefore]. It may be negative for reversals or corrections.
final class PeriodAggregationSnapshot {
  const PeriodAggregationSnapshot._({
    required this.periodStart,
    required this.periodEndExclusive,
    required this.periodSpendBefore,
    required this.periodSpendAfter,
    required this.pointsBefore,
    required this.pointsAfter,
    required this.currentIncrement,
    required this.confidence,
  });

  /// Creates a snapshot after validating its public-boundary invariants.
  factory PeriodAggregationSnapshot.validated({
    required CalculationDate periodStart,
    required CalculationDate periodEndExclusive,
    required MoneyYen periodSpendBefore,
    required MoneyYen periodSpendAfter,
    required PointAmount pointsBefore,
    required PointAmount pointsAfter,
    required PointAmount currentIncrement,
    required PeriodDataConfidence confidence,
  }) {
    if (periodStart >= periodEndExclusive) {
      throw ArgumentError.value(
        periodEndExclusive,
        'periodEndExclusive',
        'Period end must be later than period start.',
      );
    }

    if (periodSpendBefore.isNegative) {
      throw ArgumentError.value(
        periodSpendBefore,
        'periodSpendBefore',
        'Period spend before the transaction must not be negative.',
      );
    }

    if (periodSpendAfter.isNegative) {
      throw ArgumentError.value(
        periodSpendAfter,
        'periodSpendAfter',
        'Period spend after the transaction must not be negative.',
      );
    }

    if (pointsBefore.isNegative) {
      throw ArgumentError.value(
        pointsBefore,
        'pointsBefore',
        'Period points before the transaction must not be negative.',
      );
    }

    if (pointsAfter.isNegative) {
      throw ArgumentError.value(
        pointsAfter,
        'pointsAfter',
        'Period points after the transaction must not be negative.',
      );
    }

    final expectedIncrement = pointsAfter - pointsBefore;

    if (currentIncrement != expectedIncrement) {
      throw ArgumentError.value(
        currentIncrement,
        'currentIncrement',
        'Current increment must equal pointsAfter minus pointsBefore.',
      );
    }

    return PeriodAggregationSnapshot._(
      periodStart: periodStart,
      periodEndExclusive: periodEndExclusive,
      periodSpendBefore: periodSpendBefore,
      periodSpendAfter: periodSpendAfter,
      pointsBefore: pointsBefore,
      pointsAfter: pointsAfter,
      currentIncrement: currentIncrement,
      confidence: confidence,
    );
  }

  final CalculationDate periodStart;
  final CalculationDate periodEndExclusive;
  final MoneyYen periodSpendBefore;
  final MoneyYen periodSpendAfter;
  final PointAmount pointsBefore;
  final PointAmount pointsAfter;
  final PointAmount currentIncrement;
  final PeriodDataConfidence confidence;

  /// Whether [date] belongs to the half-open period.
  bool contains(CalculationDate date) {
    return date >= periodStart && date < periodEndExclusive;
  }
}

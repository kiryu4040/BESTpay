import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/domain/calculation/reward_calculation_evaluator.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';

/// Immutable increment of a period-aggregated reward.
final class PeriodIncrement {
  const PeriodIncrement({
    required this.pointsBefore,
    required this.pointsAfter,
    required this.increment,
  });

  final PointAmount pointsBefore;
  final PointAmount pointsAfter;
  final PointAmount increment;
}

/// Derives the monthly or annual increment of a reward rule.
///
/// The reward engine consumes a read-only period snapshot, so the increment
/// must be computed before evaluation. This mirrors the documented formula
/// `floor((P + A) / U) - floor(P / U)` by evaluating the very same
/// [RewardCalculation] at the period spend before and after the transaction,
/// which keeps rounding identical to the engine (D-63).
final class PeriodIncrementCalculator {
  const PeriodIncrementCalculator({
    RewardCalculationEvaluator calculationEvaluator =
        const RewardCalculationEvaluator(),
  }) : _calculationEvaluator = calculationEvaluator;

  final RewardCalculationEvaluator _calculationEvaluator;

  static const String _operation = 'periodIncrement.compute';

  AppResult<PeriodIncrement> compute({
    required RewardCalculation calculation,
    required MoneyYen periodSpendBefore,
    required MoneyYen amount,
  }) {
    if (periodSpendBefore.isNegative || amount.isNegative) {
      return AppFailure<PeriodIncrement>(
        AppError(
          code: AppErrorCode.calculationInputInvalid,
          operation: _operation,
          context: const <String, Object?>{
            'field': 'periodSpendBefore',
          },
          safeMessage: 'Period spend and amount must not be negative.',
        ),
      );
    }

    final beforeResult = _calculationEvaluator.evaluate(
      calculation: calculation,
      amount: periodSpendBefore,
    );

    return beforeResult.fold<AppResult<PeriodIncrement>>(
      onSuccess: (pointsBefore) {
        final afterResult = _calculationEvaluator.evaluate(
          calculation: calculation,
          amount: periodSpendBefore + amount,
        );

        return afterResult.fold<AppResult<PeriodIncrement>>(
          onSuccess: (pointsAfter) {
            final difference = pointsAfter - pointsBefore;

            return AppSuccess<PeriodIncrement>(
              PeriodIncrement(
                pointsBefore: pointsBefore,
                pointsAfter: pointsAfter,
                increment:
                    difference.isNegative ? PointAmount.zero : difference,
              ),
            );
          },
          onFailure: (error) => AppFailure<PeriodIncrement>(error),
        );
      },
      onFailure: (error) => AppFailure<PeriodIncrement>(error),
    );
  }
}

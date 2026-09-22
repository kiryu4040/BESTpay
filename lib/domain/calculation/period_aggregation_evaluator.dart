import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/calculation/period_aggregation_snapshot.dart';
import 'package:bestpay/domain/calculation/reward_calculation_result.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_evaluation_input.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';

/// Resolves an incremental period reward from immutable period state.
///
/// This evaluator does not derive periods, update state, or persist values.
/// It consumes a snapshot selected by [RewardAggregation.aggregationKey].
final class PeriodAggregationEvaluator {
  const PeriodAggregationEvaluator();

  static const String _operation = 'periodAggregation.evaluate';

  AppResult<RewardCalculationResult> evaluate({
    required RewardAggregation aggregation,
    required RewardEvaluationInput input,
  }) {
    if (aggregation.scope == RewardAggregationScope.transaction) {
      return _failure(
        code: AppErrorCode.calculationRuleInvalid,
        field: 'aggregation.scope',
        reason: 'transactionScopeDoesNotRequirePeriodEvaluation',
      );
    }

    final aggregationKey = aggregation.aggregationKey;
    if (aggregationKey == null) {
      return _failure(
        code: AppErrorCode.calculationRuleInvalid,
        field: 'aggregation.aggregationKey',
        reason: 'aggregationKeyRequired',
      );
    }

    if (aggregation.conditionEvaluationTiming != 'transaction') {
      return _failure(
        code: AppErrorCode.calculationRuleInvalid,
        field: 'aggregation.conditionEvaluationTiming',
        reason: 'unsupportedConditionEvaluationTiming',
        aggregationKey: aggregationKey,
      );
    }

    if (!aggregation.incrementalAward) {
      return _failure(
        code: AppErrorCode.calculationRuleInvalid,
        field: 'aggregation.incrementalAward',
        reason: 'periodEndAwardNotImplemented',
        aggregationKey: aggregationKey,
      );
    }

    final snapshot = input.periodAggregationSnapshotFor(aggregationKey);
    if (snapshot == null) {
      return AppSuccess<RewardCalculationResult>(
        RewardCalculationResult.unavailable(
          confidence: RewardConfidence.unknown,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.periodStateMissing,
          ],
        ),
      );
    }

    final confidence = switch (snapshot.confidence) {
      PeriodDataConfidence.exact => RewardConfidence.confirmed,
      PeriodDataConfidence.userEntered => RewardConfidence.estimated,
      PeriodDataConfidence.estimated => RewardConfidence.estimated,
      PeriodDataConfidence.unknown => RewardConfidence.unknown,
    };

    if (confidence == RewardConfidence.unknown) {
      return AppSuccess<RewardCalculationResult>(
        RewardCalculationResult.unavailable(
          confidence: RewardConfidence.unknown,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.periodStateUnknown,
          ],
        ),
      );
    }

    if (snapshot.periodSpendAfter < aggregation.periodMinimumEligibleSpend) {
      return AppSuccess<RewardCalculationResult>(
        RewardCalculationResult.calculated(
          points: const PointAmount(0),
          confidence: confidence,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.periodMinimumSpendNotMet,
          ],
        ),
      );
    }

    if (snapshot.currentIncrement.isNegative) {
      return _failure(
        code: AppErrorCode.calculationInputInvalid,
        field: 'periodAggregationSnapshot.currentIncrement',
        reason: 'negativeIncrementNotSupported',
        aggregationKey: aggregationKey,
      );
    }

    return AppSuccess<RewardCalculationResult>(
      RewardCalculationResult.calculated(
        points: snapshot.currentIncrement,
        confidence: confidence,
      ),
    );
  }

  AppFailure<RewardCalculationResult> _failure({
    required AppErrorCode code,
    required String field,
    required String reason,
    StableId? aggregationKey,
  }) {
    return AppFailure<RewardCalculationResult>(
      AppError(
        code: code,
        operation: _operation,
        context: <String, Object?>{
          'field': field,
          'reason': reason,
          if (aggregationKey != null) 'aggregationKey': aggregationKey.value,
        },
      ),
    );
  }
}

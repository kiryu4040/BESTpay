import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/rounding_mode.dart';
import 'package:bestpay/domain/calculation/reward_calculation_result.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';
import 'package:bestpay/domain/calculation/threshold_period_snapshot.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';

/// Evaluates one reward calculation without aggregation or rule orchestration.
///
/// Ordinary calculations are resolved directly from transaction input.
/// Threshold calculations consume a read-only snapshot, while mirror
/// orchestration is coordinated by [RewardRuleSetEvaluator].
final class RewardCalculationEvaluator {
  const RewardCalculationEvaluator();

  static const String _operation = 'rewardCalculation.evaluate';

  /// Evaluates one calculation while preserving unavailable outcomes.
  ///
  /// [periodSnapshot] is required only for threshold bonuses. Missing period
  /// state is a successful unknown result rather than a calculation failure.
  AppResult<RewardCalculationResult> evaluateResult({
    required RewardCalculation calculation,
    required MoneyYen amount,
    ThresholdPeriodSnapshot? periodSnapshot,
  }) {
    if (calculation is ThresholdBonusRewardCalculation) {
      return _evaluateThresholdBonus(
        calculation: calculation,
        amount: amount,
        periodSnapshot: periodSnapshot,
      );
    }

    final pointResult = evaluate(
      calculation: calculation,
      amount: amount,
    );

    return switch (pointResult) {
      AppSuccess<PointAmount>(value: final points) =>
        AppSuccess<RewardCalculationResult>(
          RewardCalculationResult.calculated(
            points: points,
            reasonCodes: <RewardReasonCode>[
              calculation is NoRewardCalculation
                  ? RewardReasonCode.noRewardCalculation
                  : RewardReasonCode.applied,
            ],
          ),
        ),
      AppFailure<PointAmount>(error: final error) =>
        AppFailure<RewardCalculationResult>(error),
    };
  }

  /// Applies a mirror multiplier to an already resolved source amount.
  ///
  /// Mirror calculations define no rounding mode, so fractional point results
  /// are rejected instead of being rounded implicitly.
  AppResult<RewardCalculationResult> evaluateMirror({
    required MirrorRewardCalculation calculation,
    required PointAmount sourcePoints,
  }) {
    if (sourcePoints.isNegative) {
      return _failure<RewardCalculationResult>(
        code: AppErrorCode.calculationRuleInvalid,
        calculation: calculation,
        safeMessage: 'Mirror source points must not be negative.',
        context: const <String, Object?>{
          'field': 'sourcePoints',
        },
      );
    }

    if (calculation.multiplier.isNegative) {
      return _failure<RewardCalculationResult>(
        code: AppErrorCode.calculationRuleInvalid,
        calculation: calculation,
        safeMessage: 'A mirror multiplier must not be negative.',
        context: const <String, Object?>{
          'field': 'multiplier',
        },
      );
    }

    final exactPoints =
        Rational.fromInt(sourcePoints.points) * calculation.multiplier;

    if (exactPoints.denominator != 1) {
      return _failure<RewardCalculationResult>(
        code: AppErrorCode.calculationRuleInvalid,
        calculation: calculation,
        safeMessage: 'A mirror calculation must produce whole-number points.',
        context: const <String, Object?>{
          'field': 'multiplier',
          'reason': 'nonIntegerMirrorResult',
        },
      );
    }

    return AppSuccess<RewardCalculationResult>(
      RewardCalculationResult.calculated(
        points: PointAmount(exactPoints.numerator),
      ),
    );
  }

  AppResult<PointAmount> evaluate({
    required RewardCalculation calculation,
    required MoneyYen amount,
  }) {
    if (amount.isNegative) {
      return _failure(
        code: AppErrorCode.calculationInputInvalid,
        calculation: calculation,
        safeMessage: 'The transaction amount must not be negative.',
      );
    }

    if (calculation is UnitPointsRewardCalculation) {
      return _evaluateUnitPoints(
        calculation: calculation,
        amount: amount,
      );
    }

    if (calculation is RateFractionRewardCalculation) {
      return _evaluateRateFraction(
        calculation: calculation,
        amount: amount,
      );
    }

    if (calculation is FixedPointsRewardCalculation) {
      return _validateWholePoints(
        calculation: calculation,
        points: calculation.points,
      );
    }

    if (calculation is TieredRewardCalculation) {
      return _evaluateTiered(
        calculation: calculation,
        amount: amount,
      );
    }

    if (calculation is NoRewardCalculation) {
      return const AppSuccess<PointAmount>(PointAmount.zero);
    }

    return _failure(
      code: AppErrorCode.unsupportedOperation,
      calculation: calculation,
      safeMessage:
          'This calculation requires a later reward-engine evaluation phase.',
    );
  }

  AppResult<RewardCalculationResult> _evaluateThresholdBonus({
    required ThresholdBonusRewardCalculation calculation,
    required MoneyYen amount,
    required ThresholdPeriodSnapshot? periodSnapshot,
  }) {
    if (amount.isNegative) {
      return _failure<RewardCalculationResult>(
        code: AppErrorCode.calculationInputInvalid,
        calculation: calculation,
        safeMessage: 'The transaction amount must not be negative.',
      );
    }

    if (calculation.bonusPoints.isNegative) {
      return _failure<RewardCalculationResult>(
        code: AppErrorCode.calculationRuleInvalid,
        calculation: calculation,
        safeMessage: 'Threshold bonus points must not be negative.',
        context: const <String, Object?>{
          'field': 'bonusPoints',
        },
      );
    }

    if (periodSnapshot == null) {
      return AppSuccess<RewardCalculationResult>(
        RewardCalculationResult.unavailable(
          confidence: RewardConfidence.unknown,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.periodStateMissing,
          ],
        ),
      );
    }

    if (periodSnapshot.awardsConsumed >= calculation.maxAwardsPerPeriod) {
      return AppSuccess<RewardCalculationResult>(
        RewardCalculationResult.calculated(
          points: PointAmount.zero,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.thresholdAwardLimitReached,
          ],
        ),
      );
    }

    final periodSpendAfter = periodSnapshot.periodSpendBefore + amount;
    final crossedThreshold =
        periodSnapshot.periodSpendBefore < calculation.thresholdAmount &&
            periodSpendAfter >= calculation.thresholdAmount;

    if (!crossedThreshold) {
      return AppSuccess<RewardCalculationResult>(
        RewardCalculationResult.calculated(
          points: PointAmount.zero,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.thresholdNotCrossed,
          ],
        ),
      );
    }

    return AppSuccess<RewardCalculationResult>(
      RewardCalculationResult.calculated(
        points: calculation.bonusPoints,
      ),
    );
  }

  AppResult<PointAmount> _evaluateUnitPoints({
    required UnitPointsRewardCalculation calculation,
    required MoneyYen amount,
  }) {
    final exactResult = Rational.create(
      amount.yen * calculation.pointsPerUnit.points,
      calculation.amountUnit.yen,
    );

    return switch (exactResult) {
      AppSuccess<Rational>(value: final exactPoints) => _roundPoints(
          calculation: calculation,
          exactPoints: exactPoints,
          rounding: calculation.rounding,
        ),
      AppFailure<Rational>(error: final error) =>
        AppFailure<PointAmount>(error),
    };
  }

  AppResult<PointAmount> _evaluateRateFraction({
    required RateFractionRewardCalculation calculation,
    required MoneyYen amount,
  }) {
    final exactPoints = Rational.fromInt(amount.yen) * calculation.rate;

    return _roundPoints(
      calculation: calculation,
      exactPoints: exactPoints,
      rounding: calculation.rounding,
    );
  }

  AppResult<PointAmount> _evaluateTiered({
    required TieredRewardCalculation calculation,
    required MoneyYen amount,
  }) {
    final validationFailure = _validateTiers(calculation);
    if (validationFailure != null) {
      return validationFailure;
    }

    for (final tier in calculation.tiers) {
      final maximum = tier.maximumAmountExclusive;
      final matchesMinimum = amount >= tier.minimumAmount;
      final matchesMaximum = maximum == null || amount < maximum;

      if (matchesMinimum && matchesMaximum) {
        return evaluate(
          calculation: tier.calculation,
          amount: amount,
        );
      }
    }

    return const AppSuccess<PointAmount>(PointAmount.zero);
  }

  AppFailure<PointAmount>? _validateTiers(
    TieredRewardCalculation calculation,
  ) {
    for (var index = 0; index < calculation.tiers.length; index++) {
      final tier = calculation.tiers[index];
      final maximum = tier.maximumAmountExclusive;

      if (maximum != null && maximum <= tier.minimumAmount) {
        return _failure(
          code: AppErrorCode.calculationRuleInvalid,
          calculation: calculation,
          safeMessage: 'A tier maximum must be greater than its minimum.',
          context: <String, Object?>{
            'field': 'tiers',
            'tierIndex': index,
            'reason': 'invalidTierRange',
          },
        );
      }

      if (index == 0) {
        continue;
      }

      final previous = calculation.tiers[index - 1];
      final previousMaximum = previous.maximumAmountExclusive;

      if (tier.minimumAmount <= previous.minimumAmount) {
        return _failure(
          code: AppErrorCode.calculationRuleInvalid,
          calculation: calculation,
          safeMessage: 'Tiers must use strictly ascending minimum amounts.',
          context: <String, Object?>{
            'field': 'tiers',
            'tierIndex': index,
            'reason': 'tierOrderInvalid',
          },
        );
      }

      if (previousMaximum == null) {
        return _failure(
          code: AppErrorCode.calculationRuleInvalid,
          calculation: calculation,
          safeMessage: 'An unbounded tier must be the final tier.',
          context: <String, Object?>{
            'field': 'tiers',
            'tierIndex': index,
            'reason': 'tierAfterUnboundedTier',
          },
        );
      }

      if (tier.minimumAmount < previousMaximum) {
        return _failure(
          code: AppErrorCode.calculationRuleInvalid,
          calculation: calculation,
          safeMessage: 'Tier ranges must not overlap.',
          context: <String, Object?>{
            'field': 'tiers',
            'tierIndex': index,
            'reason': 'tierRangeOverlap',
          },
        );
      }
    }

    return null;
  }

  AppResult<PointAmount> _roundPoints({
    required RewardCalculation calculation,
    required Rational exactPoints,
    required RoundingMode rounding,
  }) {
    if (exactPoints.isNegative) {
      return _failure(
        code: AppErrorCode.calculationRuleInvalid,
        calculation: calculation,
        safeMessage: 'A reward calculation must not produce negative points.',
      );
    }

    try {
      final roundedPoints = PointAmount(exactPoints.round(rounding));

      return _validateWholePoints(
        calculation: calculation,
        points: roundedPoints,
      );
    } on StateError {
      return _failure(
        code: AppErrorCode.calculationRuleInvalid,
        calculation: calculation,
        safeMessage: 'Exact rounding requires a whole-number reward result.',
        causeType: 'StateError',
      );
    }
  }

  AppResult<PointAmount> _validateWholePoints({
    required RewardCalculation calculation,
    required PointAmount points,
  }) {
    if (points.isNegative) {
      return _failure(
        code: AppErrorCode.calculationRuleInvalid,
        calculation: calculation,
        safeMessage: 'A reward calculation must not produce negative points.',
      );
    }

    return AppSuccess<PointAmount>(points);
  }

  AppFailure<T> _failure<T>({
    required AppErrorCode code,
    required RewardCalculation calculation,
    required String safeMessage,
    String? causeType,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    return AppFailure<T>(
      AppError(
        code: code,
        operation: _operation,
        context: <String, Object?>{
          'calculationType': _calculationType(calculation),
          ...context,
        },
        safeMessage: safeMessage,
        causeType: causeType,
      ),
    );
  }

  String _calculationType(RewardCalculation calculation) {
    if (calculation is UnitPointsRewardCalculation) {
      return 'unitPoints';
    }
    if (calculation is RateFractionRewardCalculation) {
      return 'rateFraction';
    }
    if (calculation is FixedPointsRewardCalculation) {
      return 'fixedPoints';
    }
    if (calculation is MirrorRewardCalculation) {
      return 'mirror';
    }
    if (calculation is ThresholdBonusRewardCalculation) {
      return 'thresholdBonus';
    }
    if (calculation is TieredRewardCalculation) {
      return 'tiered';
    }
    if (calculation is NoRewardCalculation) {
      return 'none';
    }

    return 'unknown';
  }
}

import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/rounding_mode.dart';
import 'package:bestpay/domain/calculation/reward_calculation_evaluator.dart';
import 'package:bestpay/domain/calculation/reward_calculation_result.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';
import 'package:bestpay/domain/calculation/threshold_period_snapshot.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = RewardCalculationEvaluator();

  group('unitPoints', () {
    test('calculates an exact whole-number result', () {
      final result = evaluator.evaluate(
        calculation: UnitPointsRewardCalculation(
          amountUnit: const MoneyYen(200),
          pointsPerUnit: const PointAmount(2),
          rounding: RoundingMode.exact,
        ),
        amount: const MoneyYen(1000),
      );

      expect(_success(result), const PointAmount(10));
    });

    test('applies floor and ceiling to the final rational result', () {
      final floorResult = evaluator.evaluate(
        calculation: UnitPointsRewardCalculation(
          amountUnit: const MoneyYen(200),
          pointsPerUnit: const PointAmount(1),
          rounding: RoundingMode.floor,
        ),
        amount: const MoneyYen(250),
      );

      final ceilingResult = evaluator.evaluate(
        calculation: UnitPointsRewardCalculation(
          amountUnit: const MoneyYen(200),
          pointsPerUnit: const PointAmount(1),
          rounding: RoundingMode.ceiling,
        ),
        amount: const MoneyYen(250),
      );

      expect(_success(floorResult), const PointAmount(1));
      expect(_success(ceilingResult), const PointAmount(2));
    });

    test('multiplies before rounding instead of rounding units first', () {
      final result = evaluator.evaluate(
        calculation: UnitPointsRewardCalculation(
          amountUnit: const MoneyYen(200),
          pointsPerUnit: const PointAmount(3),
          rounding: RoundingMode.floor,
        ),
        amount: const MoneyYen(100),
      );

      expect(_success(result), const PointAmount(1));
    });
  });

  group('rateFraction', () {
    test('calculates points using exact rational arithmetic', () {
      final result = evaluator.evaluate(
        calculation: RateFractionRewardCalculation(
          rate: _rational(1, 100),
          rounding: RoundingMode.floor,
        ),
        amount: const MoneyYen(1250),
      );

      expect(_success(result), const PointAmount(12));
    });

    test('supports half-to-even rounding', () {
      final roundsDown = evaluator.evaluate(
        calculation: RateFractionRewardCalculation(
          rate: _rational(1, 2),
          rounding: RoundingMode.halfToEven,
        ),
        amount: const MoneyYen(5),
      );

      final roundsUp = evaluator.evaluate(
        calculation: RateFractionRewardCalculation(
          rate: _rational(1, 2),
          rounding: RoundingMode.halfToEven,
        ),
        amount: const MoneyYen(7),
      );

      expect(_success(roundsDown), const PointAmount(2));
      expect(_success(roundsUp), const PointAmount(4));
    });
  });

  group('fixedPoints and none', () {
    test('returns fixed points once', () {
      final result = evaluator.evaluate(
        calculation: const FixedPointsRewardCalculation(
          PointAmount(50),
        ),
        amount: const MoneyYen(0),
      );

      expect(_success(result), const PointAmount(50));
    });

    test('none returns zero points', () {
      final result = evaluator.evaluate(
        calculation: const NoRewardCalculation(),
        amount: const MoneyYen(5000),
      );

      expect(_success(result), PointAmount.zero);
    });
  });

  group('tiered', () {
    test('uses half-open boundaries and applies the selected tier', () {
      final calculation = TieredRewardCalculation(<RewardTier>[
        RewardTier(
          minimumAmount: const MoneyYen(0),
          maximumAmountExclusive: const MoneyYen(1000),
          calculation: const FixedPointsRewardCalculation(
            PointAmount(10),
          ),
        ),
        RewardTier(
          minimumAmount: const MoneyYen(1000),
          maximumAmountExclusive: null,
          calculation: const FixedPointsRewardCalculation(
            PointAmount(20),
          ),
        ),
      ]);

      expect(
        _success(
          evaluator.evaluate(
            calculation: calculation,
            amount: const MoneyYen(999),
          ),
        ),
        const PointAmount(10),
      );
      expect(
        _success(
          evaluator.evaluate(
            calculation: calculation,
            amount: const MoneyYen(1000),
          ),
        ),
        const PointAmount(20),
      );
    });

    test('applies the selected calculation to the entire amount', () {
      final calculation = TieredRewardCalculation(<RewardTier>[
        RewardTier(
          minimumAmount: const MoneyYen(0),
          maximumAmountExclusive: const MoneyYen(1000),
          calculation: const FixedPointsRewardCalculation(
            PointAmount(1),
          ),
        ),
        RewardTier(
          minimumAmount: const MoneyYen(1000),
          maximumAmountExclusive: null,
          calculation: RateFractionRewardCalculation(
            rate: _rational(1, 100),
            rounding: RoundingMode.floor,
          ),
        ),
      ]);

      final result = evaluator.evaluate(
        calculation: calculation,
        amount: const MoneyYen(1500),
      );

      expect(_success(result), const PointAmount(15));
    });

    test('allows gaps and returns zero when no tier matches', () {
      final calculation = TieredRewardCalculation(<RewardTier>[
        RewardTier(
          minimumAmount: const MoneyYen(0),
          maximumAmountExclusive: const MoneyYen(100),
          calculation: const FixedPointsRewardCalculation(
            PointAmount(10),
          ),
        ),
        RewardTier(
          minimumAmount: const MoneyYen(200),
          maximumAmountExclusive: null,
          calculation: const FixedPointsRewardCalculation(
            PointAmount(20),
          ),
        ),
      ]);

      final result = evaluator.evaluate(
        calculation: calculation,
        amount: const MoneyYen(150),
      );

      expect(_success(result), PointAmount.zero);
    });

    test('rejects a tier whose maximum is not above its minimum', () {
      final calculation = TieredRewardCalculation(<RewardTier>[
        RewardTier(
          minimumAmount: const MoneyYen(100),
          maximumAmountExclusive: const MoneyYen(50),
          calculation: const FixedPointsRewardCalculation(
            PointAmount(10),
          ),
        ),
      ]);

      final error = _failure(
        evaluator.evaluate(
          calculation: calculation,
          amount: const MoneyYen(100),
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['calculationType'], 'tiered');
      expect(error.context['reason'], 'invalidTierRange');
      expect(error.context['tierIndex'], 0);
    });

    test('rejects tiers that are not in ascending order', () {
      final calculation = TieredRewardCalculation(<RewardTier>[
        RewardTier(
          minimumAmount: const MoneyYen(1000),
          maximumAmountExclusive: const MoneyYen(2000),
          calculation: const FixedPointsRewardCalculation(
            PointAmount(20),
          ),
        ),
        RewardTier(
          minimumAmount: const MoneyYen(0),
          maximumAmountExclusive: const MoneyYen(1000),
          calculation: const FixedPointsRewardCalculation(
            PointAmount(10),
          ),
        ),
      ]);

      final error = _failure(
        evaluator.evaluate(
          calculation: calculation,
          amount: const MoneyYen(500),
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['reason'], 'tierOrderInvalid');
      expect(error.context['tierIndex'], 1);
    });

    test('rejects overlapping tiers before selecting a result', () {
      final calculation = TieredRewardCalculation(<RewardTier>[
        RewardTier(
          minimumAmount: const MoneyYen(0),
          maximumAmountExclusive: const MoneyYen(1000),
          calculation: const FixedPointsRewardCalculation(
            PointAmount(10),
          ),
        ),
        RewardTier(
          minimumAmount: const MoneyYen(500),
          maximumAmountExclusive: null,
          calculation: const FixedPointsRewardCalculation(
            PointAmount(20),
          ),
        ),
      ]);

      final error = _failure(
        evaluator.evaluate(
          calculation: calculation,
          amount: const MoneyYen(100),
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['reason'], 'tierRangeOverlap');
      expect(error.context['tierIndex'], 1);
    });

    test('rejects a tier after an unbounded tier', () {
      final calculation = TieredRewardCalculation(<RewardTier>[
        RewardTier(
          minimumAmount: const MoneyYen(0),
          maximumAmountExclusive: null,
          calculation: const FixedPointsRewardCalculation(
            PointAmount(10),
          ),
        ),
        RewardTier(
          minimumAmount: const MoneyYen(1000),
          maximumAmountExclusive: null,
          calculation: const FixedPointsRewardCalculation(
            PointAmount(20),
          ),
        ),
      ]);

      final error = _failure(
        evaluator.evaluate(
          calculation: calculation,
          amount: const MoneyYen(1500),
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['reason'], 'tierAfterUnboundedTier');
      expect(error.context['tierIndex'], 1);
    });
  });
  group('result-aware evaluation', () {
    test('wraps ordinary calculations without changing their points', () {
      final result = evaluator.evaluateResult(
        calculation: const FixedPointsRewardCalculation(
          PointAmount(25),
        ),
        amount: const MoneyYen(1000),
      );

      final value = _resultSuccess(result);
      expect(value.points, const PointAmount(25));
      expect(value.confidence, RewardConfidence.confirmed);
      expect(
        value.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.applied],
      );
    });

    test('uses noRewardCalculation for none', () {
      final result = evaluator.evaluateResult(
        calculation: const NoRewardCalculation(),
        amount: const MoneyYen(1000),
      );

      final value = _resultSuccess(result);
      expect(value.points, PointAmount.zero);
      expect(
        value.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.noRewardCalculation,
        ],
      );
    });
  });

  group('mirror arithmetic', () {
    test('multiplies resolved source points exactly', () {
      final result = evaluator.evaluateMirror(
        calculation: MirrorRewardCalculation(
          sourceRuleId: _id('source_rule'),
          multiplier: _rational(3, 2),
          inheritEligibility: false,
          inheritExclusions: false,
          useFinalSourceAmount: true,
        ),
        sourcePoints: const PointAmount(100),
      );

      final value = _resultSuccess(result);
      expect(value.points, const PointAmount(150));
      expect(
        value.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.applied],
      );
    });

    test('allows a fractional multiplier with an integer result', () {
      final result = evaluator.evaluateMirror(
        calculation: MirrorRewardCalculation(
          sourceRuleId: _id('source_rule'),
          multiplier: _rational(1, 2),
          inheritEligibility: false,
          inheritExclusions: false,
          useFinalSourceAmount: false,
        ),
        sourcePoints: const PointAmount(10),
      );

      expect(
        _resultSuccess(result).points,
        const PointAmount(5),
      );
    });

    test('rejects a non-integer result without rounding', () {
      final result = evaluator.evaluateMirror(
        calculation: MirrorRewardCalculation(
          sourceRuleId: _id('source_rule'),
          multiplier: _rational(1, 2),
          inheritEligibility: false,
          inheritExclusions: false,
          useFinalSourceAmount: true,
        ),
        sourcePoints: const PointAmount(5),
      );

      final error = _resultFailure(result);
      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.operation, 'rewardCalculation.evaluate');
      expect(error.context['calculationType'], 'mirror');
      expect(error.context['field'], 'multiplier');
      expect(error.context['reason'], 'nonIntegerMirrorResult');
    });

    test('rejects a negative multiplier', () {
      final result = evaluator.evaluateMirror(
        calculation: MirrorRewardCalculation(
          sourceRuleId: _id('source_rule'),
          multiplier: _rational(-1, 1),
          inheritEligibility: false,
          inheritExclusions: false,
          useFinalSourceAmount: true,
        ),
        sourcePoints: const PointAmount(10),
      );

      final error = _resultFailure(result);
      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['field'], 'multiplier');
    });

    test('rejects negative source points', () {
      final result = evaluator.evaluateMirror(
        calculation: MirrorRewardCalculation(
          sourceRuleId: _id('source_rule'),
          multiplier: Rational.one,
          inheritEligibility: false,
          inheritExclusions: false,
          useFinalSourceAmount: true,
        ),
        sourcePoints: const PointAmount(-1),
      );

      final error = _resultFailure(result);
      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['field'], 'sourcePoints');
    });
  });
  group('thresholdBonus', () {
    test('returns unknown when the period snapshot is missing', () {
      final result = evaluator.evaluateResult(
        calculation: ThresholdBonusRewardCalculation(
          thresholdAmount: const MoneyYen(1000),
          bonusPoints: const PointAmount(100),
          maxAwardsPerPeriod: 1,
        ),
        amount: const MoneyYen(200),
      );

      final value = _resultSuccess(result);
      expect(value.isCalculated, isFalse);
      expect(value.points, isNull);
      expect(value.confidence, RewardConfidence.unknown);
      expect(
        value.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.periodStateMissing,
        ],
      );
    });

    test('awards the bonus when the threshold is newly crossed', () {
      final snapshot = ThresholdPeriodSnapshot.validated(
        periodSpendBefore: const MoneyYen(900),
        awardsConsumed: 0,
      );

      final result = evaluator.evaluateResult(
        calculation: ThresholdBonusRewardCalculation(
          thresholdAmount: const MoneyYen(1000),
          bonusPoints: const PointAmount(100),
          maxAwardsPerPeriod: 1,
        ),
        amount: const MoneyYen(100),
        periodSnapshot: snapshot,
      );

      final value = _resultSuccess(result);
      expect(value.points, const PointAmount(100));
      expect(value.confidence, RewardConfidence.confirmed);
      expect(
        value.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.applied],
      );

      expect(snapshot.periodSpendBefore, const MoneyYen(900));
      expect(snapshot.awardsConsumed, 0);
    });

    test('does not award before the threshold is reached', () {
      final result = evaluator.evaluateResult(
        calculation: ThresholdBonusRewardCalculation(
          thresholdAmount: const MoneyYen(1000),
          bonusPoints: const PointAmount(100),
          maxAwardsPerPeriod: 1,
        ),
        amount: const MoneyYen(99),
        periodSnapshot: ThresholdPeriodSnapshot.validated(
          periodSpendBefore: const MoneyYen(900),
          awardsConsumed: 0,
        ),
      );

      final value = _resultSuccess(result);
      expect(value.points, PointAmount.zero);
      expect(
        value.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.thresholdNotCrossed,
        ],
      );
    });

    test('does not award when the threshold was already reached', () {
      final result = evaluator.evaluateResult(
        calculation: ThresholdBonusRewardCalculation(
          thresholdAmount: const MoneyYen(1000),
          bonusPoints: const PointAmount(100),
          maxAwardsPerPeriod: 2,
        ),
        amount: const MoneyYen(500),
        periodSnapshot: ThresholdPeriodSnapshot.validated(
          periodSpendBefore: const MoneyYen(1000),
          awardsConsumed: 1,
        ),
      );

      final value = _resultSuccess(result);
      expect(value.points, PointAmount.zero);
      expect(
        value.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.thresholdNotCrossed,
        ],
      );
    });

    test('does not award after the period award limit is reached', () {
      final result = evaluator.evaluateResult(
        calculation: ThresholdBonusRewardCalculation(
          thresholdAmount: const MoneyYen(1000),
          bonusPoints: const PointAmount(100),
          maxAwardsPerPeriod: 1,
        ),
        amount: const MoneyYen(100),
        periodSnapshot: ThresholdPeriodSnapshot.validated(
          periodSpendBefore: const MoneyYen(900),
          awardsConsumed: 1,
        ),
      );

      final value = _resultSuccess(result);
      expect(value.points, PointAmount.zero);
      expect(
        value.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.thresholdAwardLimitReached,
        ],
      );
    });

    test('rejects negative bonus points as an invalid rule', () {
      final result = evaluator.evaluateResult(
        calculation: ThresholdBonusRewardCalculation(
          thresholdAmount: const MoneyYen(1000),
          bonusPoints: const PointAmount(-1),
          maxAwardsPerPeriod: 1,
        ),
        amount: const MoneyYen(100),
        periodSnapshot: ThresholdPeriodSnapshot.validated(
          periodSpendBefore: const MoneyYen(900),
          awardsConsumed: 0,
        ),
      );

      final error = _resultFailure(result);
      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['calculationType'], 'thresholdBonus');
      expect(error.context['field'], 'bonusPoints');
    });

    test('rejects a negative transaction before checking period state', () {
      final result = evaluator.evaluateResult(
        calculation: ThresholdBonusRewardCalculation(
          thresholdAmount: const MoneyYen(1000),
          bonusPoints: const PointAmount(100),
          maxAwardsPerPeriod: 1,
        ),
        amount: const MoneyYen(-1),
      );

      expect(
        _resultFailure(result).code,
        AppErrorCode.calculationInputInvalid,
      );
    });
  });
  group('structured failures', () {
    test('rejects a negative transaction amount', () {
      final result = evaluator.evaluate(
        calculation: const FixedPointsRewardCalculation(
          PointAmount(10),
        ),
        amount: const MoneyYen(-1),
      );

      final error = _failure(result);
      expect(error.code, AppErrorCode.calculationInputInvalid);
      expect(error.operation, 'rewardCalculation.evaluate');
      expect(error.context['calculationType'], 'fixedPoints');
    });

    test('rejects negative fixed points', () {
      final result = evaluator.evaluate(
        calculation: const FixedPointsRewardCalculation(
          PointAmount(-1),
        ),
        amount: const MoneyYen(1000),
      );

      expect(
        _failure(result).code,
        AppErrorCode.calculationRuleInvalid,
      );
    });

    test('rejects a negative rate result before rounding', () {
      final result = evaluator.evaluate(
        calculation: RateFractionRewardCalculation(
          rate: _rational(-1, 100),
          rounding: RoundingMode.towardZero,
        ),
        amount: const MoneyYen(1),
      );

      expect(
        _failure(result).code,
        AppErrorCode.calculationRuleInvalid,
      );
    });

    test('returns a rule failure for fractional exact rounding', () {
      final result = evaluator.evaluate(
        calculation: RateFractionRewardCalculation(
          rate: _rational(1, 2),
          rounding: RoundingMode.exact,
        ),
        amount: const MoneyYen(1),
      );

      final error = _failure(result);
      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.causeType, 'StateError');
      expect(error.context['calculationType'], 'rateFraction');
    });
  });
}

RewardCalculationResult _resultSuccess(
  AppResult<RewardCalculationResult> result,
) {
  expect(result, isA<AppSuccess<RewardCalculationResult>>());
  return (result as AppSuccess<RewardCalculationResult>).value;
}

AppError _resultFailure(
  AppResult<RewardCalculationResult> result,
) {
  expect(result, isA<AppFailure<RewardCalculationResult>>());
  return (result as AppFailure<RewardCalculationResult>).error;
}

PointAmount _success(AppResult<PointAmount> result) {
  expect(result, isA<AppSuccess<PointAmount>>());
  return (result as AppSuccess<PointAmount>).value;
}

AppError _failure(AppResult<PointAmount> result) {
  expect(result, isA<AppFailure<PointAmount>>());
  return (result as AppFailure<PointAmount>).error;
}

Rational _rational(int numerator, int denominator) {
  final result = Rational.create(numerator, denominator);
  expect(result, isA<AppSuccess<Rational>>());
  return (result as AppSuccess<Rational>).value;
}

StableId _id(String value) {
  final result = StableId.create(value);
  if (result is AppSuccess<StableId>) {
    return result.value;
  }

  throw StateError('Invalid test StableId: $value');
}

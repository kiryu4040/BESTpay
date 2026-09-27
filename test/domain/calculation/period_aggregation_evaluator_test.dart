import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/calculation/period_aggregation_evaluator.dart';
import 'package:bestpay/domain/calculation/period_aggregation_snapshot.dart';
import 'package:bestpay/domain/calculation/reward_calculation_result.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_evaluation_input.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = PeriodAggregationEvaluator();

  group('PeriodAggregationEvaluator', () {
    test('returns the exact current increment as confirmed points', () {
      final key = _id('aggregation_one');
      final snapshot = _snapshot(
        currentIncrement: const PointAmount(5),
        pointsBefore: const PointAmount(10),
        pointsAfter: const PointAmount(15),
      );

      final result = _success(
        evaluator.evaluate(
          aggregation: _aggregation(aggregationKey: key),
          input: _input(
            snapshots: <StableId, PeriodAggregationSnapshot>{
              key: snapshot,
            },
          ),
        ),
      );

      expect(result.points, const PointAmount(5));
      expect(result.confidence, RewardConfidence.confirmed);
      expect(
        result.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.applied],
      );
    });

    test('maps user-entered and estimated data to estimated confidence', () {
      final key = _id('aggregation_one');

      for (final confidence in <PeriodDataConfidence>[
        PeriodDataConfidence.userEntered,
        PeriodDataConfidence.estimated,
      ]) {
        final result = _success(
          evaluator.evaluate(
            aggregation: _aggregation(aggregationKey: key),
            input: _input(
              snapshots: <StableId, PeriodAggregationSnapshot>{
                key: _snapshot(confidence: confidence),
              },
            ),
          ),
        );

        expect(result.points, const PointAmount(5));
        expect(result.confidence, RewardConfidence.estimated);
      }
    });

    test('returns unknown when the snapshot confidence is unknown', () {
      final key = _id('aggregation_one');

      final result = _success(
        evaluator.evaluate(
          aggregation: _aggregation(aggregationKey: key),
          input: _input(
            snapshots: <StableId, PeriodAggregationSnapshot>{
              key: _snapshot(
                confidence: PeriodDataConfidence.unknown,
              ),
            },
          ),
        ),
      );

      expect(result.points, isNull);
      expect(result.confidence, RewardConfidence.unknown);
      expect(
        result.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.periodStateUnknown,
        ],
      );
    });

    test('returns unknown when the keyed snapshot is missing', () {
      final result = _success(
        evaluator.evaluate(
          aggregation: _aggregation(
            aggregationKey: _id('aggregation_one'),
          ),
          input: _input(),
        ),
      );

      expect(result.points, isNull);
      expect(result.confidence, RewardConfidence.unknown);
      expect(
        result.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.periodStateMissing,
        ],
      );
    });

    test('returns zero when period minimum eligible spend is not met', () {
      final key = _id('aggregation_one');

      final result = _success(
        evaluator.evaluate(
          aggregation: _aggregation(
            aggregationKey: key,
            periodMinimumEligibleSpend: const MoneyYen(2000),
          ),
          input: _input(
            snapshots: <StableId, PeriodAggregationSnapshot>{
              key: _snapshot(
                periodSpendAfter: const MoneyYen(1500),
              ),
            },
          ),
        ),
      );

      expect(result.points, PointAmount.zero);
      expect(result.confidence, RewardConfidence.confirmed);
      expect(
        result.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.periodMinimumSpendNotMet,
        ],
      );
    });

    test('rejects a negative current increment at the result boundary', () {
      final key = _id('aggregation_one');

      final error = _failure(
        evaluator.evaluate(
          aggregation: _aggregation(aggregationKey: key),
          input: _input(
            snapshots: <StableId, PeriodAggregationSnapshot>{
              key: _snapshot(
                pointsBefore: const PointAmount(10),
                pointsAfter: const PointAmount(5),
                currentIncrement: const PointAmount(-5),
              ),
            },
          ),
        ),
      );

      expect(error.code, AppErrorCode.calculationInputInvalid);
      expect(error.operation, 'periodAggregation.evaluate');
      expect(
        error.context['field'],
        'periodAggregationSnapshot.currentIncrement',
      );
      expect(
        error.context['reason'],
        'negativeIncrementNotSupported',
      );
      expect(error.context['aggregationKey'], 'aggregation_one');
    });

    test('rejects transaction scope at the period evaluator boundary', () {
      final error = _failure(
        evaluator.evaluate(
          aggregation: _aggregation(
            scope: RewardAggregationScope.transaction,
            aggregationKey: null,
          ),
          input: _input(),
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['field'], 'aggregation.scope');
      expect(
        error.context['reason'],
        'transactionScopeDoesNotRequirePeriodEvaluation',
      );
    });

    test('requires an aggregation key for period scope', () {
      final error = _failure(
        evaluator.evaluate(
          aggregation: _aggregation(aggregationKey: null),
          input: _input(),
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(
        error.context['field'],
        'aggregation.aggregationKey',
      );
      expect(error.context['reason'], 'aggregationKeyRequired');
    });

    test('rejects period-end award semantics until implemented', () {
      final key = _id('aggregation_one');

      final error = _failure(
        evaluator.evaluate(
          aggregation: _aggregation(
            aggregationKey: key,
            incrementalAward: false,
          ),
          input: _input(),
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(
        error.context['field'],
        'aggregation.incrementalAward',
      );
      expect(error.context['reason'], 'periodEndAwardNotImplemented');
    });

    test('rejects unsupported condition evaluation timing', () {
      final key = _id('aggregation_one');

      final error = _failure(
        evaluator.evaluate(
          aggregation: _aggregation(
            aggregationKey: key,
            conditionEvaluationTiming: 'periodEnd',
          ),
          input: _input(),
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(
        error.context['field'],
        'aggregation.conditionEvaluationTiming',
      );
      expect(
        error.context['reason'],
        'unsupportedConditionEvaluationTiming',
      );
    });
  });
}

RewardAggregation _aggregation({
  RewardAggregationScope scope = RewardAggregationScope.calendarMonth,
  required StableId? aggregationKey,
  MoneyYen periodMinimumEligibleSpend = MoneyYen.zero,
  String conditionEvaluationTiming = 'transaction',
  bool incrementalAward = true,
}) {
  return RewardAggregation(
    scope: scope,
    aggregationKey: aggregationKey,
    periodMinimumEligibleSpend: periodMinimumEligibleSpend,
    conditionEvaluationTiming: conditionEvaluationTiming,
    incrementalAward: incrementalAward,
  );
}

RewardEvaluationInput _input({
  Map<StableId, PeriodAggregationSnapshot> snapshots =
      const <StableId, PeriodAggregationSnapshot>{},
}) {
  return RewardEvaluationInput(
    amount: MoneyYen.zero,
    instrumentId: null,
    modeId: null,
    routeId: null,
    merchantId: null,
    conditionContext: ConditionEvaluationContext(),
    periodAggregationSnapshots: snapshots,
  );
}

PeriodAggregationSnapshot _snapshot({
  MoneyYen periodSpendBefore = const MoneyYen(1000),
  MoneyYen periodSpendAfter = const MoneyYen(1500),
  PointAmount pointsBefore = const PointAmount(10),
  PointAmount pointsAfter = const PointAmount(15),
  PointAmount currentIncrement = const PointAmount(5),
  PeriodDataConfidence confidence = PeriodDataConfidence.exact,
}) {
  return PeriodAggregationSnapshot.validated(
    periodStart: _date('2026-06-01'),
    periodEndExclusive: _date('2026-07-01'),
    periodSpendBefore: periodSpendBefore,
    periodSpendAfter: periodSpendAfter,
    pointsBefore: pointsBefore,
    pointsAfter: pointsAfter,
    currentIncrement: currentIncrement,
    confidence: confidence,
  );
}

RewardCalculationResult _success(
  AppResult<RewardCalculationResult> result,
) {
  expect(result, isA<AppSuccess<RewardCalculationResult>>());
  return (result as AppSuccess<RewardCalculationResult>).value;
}

AppError _failure(
  AppResult<RewardCalculationResult> result,
) {
  expect(result, isA<AppFailure<RewardCalculationResult>>());
  return (result as AppFailure<RewardCalculationResult>).error;
}

CalculationDate _date(String value) {
  final result = CalculationDate.parse(value);
  expect(result, isA<AppSuccess<CalculationDate>>());
  return (result as AppSuccess<CalculationDate>).value;
}

StableId _id(String value) {
  final result = StableId.create(value);
  expect(result, isA<AppSuccess<StableId>>());
  return (result as AppSuccess<StableId>).value;
}

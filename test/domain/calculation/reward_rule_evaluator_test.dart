import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/core/value_objects/validity_period.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/calculation/period_aggregation_snapshot.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_evaluation_input.dart';
import 'package:bestpay/domain/calculation/reward_rule_eligibility_result.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';
import 'package:bestpay/domain/calculation/reward_rule_evaluation_result.dart';
import 'package:bestpay/domain/calculation/reward_rule_evaluator.dart';
import 'package:bestpay/domain/calculation/threshold_period_snapshot.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/condition_models.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = RewardRuleEvaluator();

  group('RewardRuleEvaluator selectors and exclusions', () {
    test('applies a rule when every populated selector axis matches', () {
      final input = _populatedInput();
      final rule = _rule(
        selectors: _selectors(
          instrumentIds: <StableId>[_id('instrument_one')],
          modeIds: <StableId>[_id('mode_one')],
          routeIds: <StableId>[_id('route_one')],
          fundingRelationIds: <StableId>[_id('funding_one')],
          merchantIds: <StableId>[_id('merchant_one')],
          merchantGroupIds: <StableId>[_id('merchant_group_one')],
          categoryIds: <StableId>[_id('category_one')],
          brandIds: <StableId>[_id('brand_one')],
          locationIds: <StableId>[_id('location_one')],
          transactionTags: <StableId>[_id('transaction_tag_one')],
        ),
      );

      final result = _success(evaluator.evaluate(rule: rule, input: input));

      expect(result.points, const PointAmount(25));
      expect(result.eligibility, TriState.satisfied);
      expect(
        result.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.applied],
      );
    });

    test('requires every populated selector axis to match', () {
      final other = _id('other_value');
      final mismatchSelectors = <SelectorSet>[
        _selectors(instrumentIds: <StableId>[other]),
        _selectors(modeIds: <StableId>[other]),
        _selectors(routeIds: <StableId>[other]),
        _selectors(fundingRelationIds: <StableId>[other]),
        _selectors(merchantIds: <StableId>[other]),
        _selectors(merchantGroupIds: <StableId>[other]),
        _selectors(categoryIds: <StableId>[other]),
        _selectors(brandIds: <StableId>[other]),
        _selectors(locationIds: <StableId>[other]),
        _selectors(transactionTags: <StableId>[other]),
      ];

      for (final selectors in mismatchSelectors) {
        final result = _success(
          evaluator.evaluate(
            rule: _rule(selectors: selectors),
            input: _populatedInput(),
          ),
        );

        expect(result.eligibility, TriState.notSatisfied);
        expect(result.points, PointAmount.zero);
        expect(
          result.reasonCodes,
          const <RewardReasonCode>[
            RewardReasonCode.selectorMismatch,
          ],
        );
      }
    });

    test('checks every exclusion axis before selector mismatch', () {
      final actualExclusions = <SelectorSet>[
        _selectors(instrumentIds: <StableId>[_id('instrument_one')]),
        _selectors(modeIds: <StableId>[_id('mode_one')]),
        _selectors(routeIds: <StableId>[_id('route_one')]),
        _selectors(fundingRelationIds: <StableId>[_id('funding_one')]),
        _selectors(merchantIds: <StableId>[_id('merchant_one')]),
        _selectors(
          merchantGroupIds: <StableId>[_id('merchant_group_one')],
        ),
        _selectors(categoryIds: <StableId>[_id('category_one')]),
        _selectors(brandIds: <StableId>[_id('brand_one')]),
        _selectors(locationIds: <StableId>[_id('location_one')]),
        _selectors(
          transactionTags: <StableId>[_id('transaction_tag_one')],
        ),
      ];

      for (final exclusions in actualExclusions) {
        final result = _success(
          evaluator.evaluate(
            rule: _rule(
              selectors: _selectors(
                instrumentIds: <StableId>[_id('other_instrument')],
              ),
              exclusions: exclusions,
            ),
            input: _populatedInput(),
          ),
        );

        expect(result.eligibility, TriState.notSatisfied);
        expect(
          result.reasonCodes,
          const <RewardReasonCode>[RewardReasonCode.excluded],
        );
      }
    });
  });

  group('RewardRuleEvaluator dates', () {
    test('uses every RewardDateBasis', () {
      final start = _date('2026-06-01');
      final end = _date('2026-06-02');
      final input = _populatedInput(allDates: start);

      for (final basis in RewardDateBasis.values) {
        final result = _success(
          evaluator.evaluate(
            rule: _rule(
              dateBasis: basis,
              validityPeriod: _period(start, end),
            ),
            input: input,
          ),
        );

        expect(result.points, const PointAmount(25));
      }
    });

    test('returns unknown when the selected date is missing', () {
      final result = _success(
        evaluator.evaluate(
          rule: _rule(dateBasis: RewardDateBasis.postingDate),
          input: _input(transactionDate: _date('2026-06-01')),
        ),
      );

      expect(result.points, isNull);
      expect(result.eligibility, TriState.unknown);
      expect(result.confidence, RewardConfidence.unknown);
      expect(
        result.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.missingDateBasis],
      );
    });

    test('uses half-open validity boundaries', () {
      final start = _date('2026-06-01');
      final end = _date('2026-06-02');
      final rule = _rule(validityPeriod: _period(start, end));

      final atStart = _success(
        evaluator.evaluate(
          rule: rule,
          input: _input(transactionDate: start),
        ),
      );
      final atEnd = _success(
        evaluator.evaluate(
          rule: rule,
          input: _input(transactionDate: end),
        ),
      );

      expect(atStart.points, const PointAmount(25));
      expect(atEnd.eligibility, TriState.notSatisfied);
      expect(
        atEnd.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.outsideValidityPeriod,
        ],
      );
    });
  });

  group('RewardRuleEvaluator conditions', () {
    test('maps all four condition states to rule outcomes', () {
      final conditionId = _id('condition_one');
      final cases = <({
        TriState state,
        TriState eligibility,
        RewardConfidence confidence,
        RewardReasonCode reason,
        PointAmount? points,
      })>[
        (
          state: TriState.satisfied,
          eligibility: TriState.satisfied,
          confidence: RewardConfidence.confirmed,
          reason: RewardReasonCode.applied,
          points: const PointAmount(25),
        ),
        (
          state: TriState.notSatisfied,
          eligibility: TriState.notSatisfied,
          confidence: RewardConfidence.ineligible,
          reason: RewardReasonCode.conditionNotSatisfied,
          points: PointAmount.zero,
        ),
        (
          state: TriState.unknown,
          eligibility: TriState.unknown,
          confidence: RewardConfidence.conditional,
          reason: RewardReasonCode.conditionUnknown,
          points: null,
        ),
        (
          state: TriState.notApplicable,
          eligibility: TriState.notSatisfied,
          confidence: RewardConfidence.ineligible,
          reason: RewardReasonCode.conditionNotSatisfied,
          points: PointAmount.zero,
        ),
      ];

      for (final testCase in cases) {
        final result = _success(
          evaluator.evaluate(
            rule: _rule(
              conditionExpression: ConditionReferenceExpression(conditionId),
            ),
            input: _input(
              transactionDate: _date('2026-06-01'),
              conditionContext: ConditionEvaluationContext(
                states: <StableId, TriState>{
                  conditionId: testCase.state,
                },
              ),
            ),
          ),
        );

        expect(result.eligibility, testCase.eligibility);
        expect(result.confidence, testCase.confidence);
        expect(result.points, testCase.points);
        expect(
          result.reasonCodes,
          <RewardReasonCode>[testCase.reason],
        );
      }
    });

    test('propagates structured condition failures', () {
      final conditionId = _id('condition_one');
      final result = evaluator.evaluate(
        rule: _rule(
          conditionExpression: ComparisonConditionExpression(
            conditionId: conditionId,
            operator: ComparisonOperator.equals,
            value: const IntegerConditionComparisonValue(10),
          ),
        ),
        input: _input(
          transactionDate: _date('2026-06-01'),
          conditionContext: ConditionEvaluationContext(
            values: <StableId, Object?>{
              conditionId: '10',
            },
          ),
        ),
      );

      final error = _failure(result);
      expect(error.code, AppErrorCode.calculationInputInvalid);
      expect(error.operation, 'calculation.condition.evaluate');
    });
  });

  group('RewardRuleEvaluator eligibility boundary', () {
    test('does not require threshold state during eligibility evaluation', () {
      final calculation = ThresholdBonusRewardCalculation(
        thresholdAmount: const MoneyYen(1000),
        bonusPoints: const PointAmount(100),
        maxAwardsPerPeriod: 1,
      );
      final rule = _rule(calculation: calculation);
      final input = _input(
        amount: const MoneyYen(100),
        transactionDate: _date('2026-06-01'),
      );

      final eligibility = _eligibilitySuccess(
        evaluator.evaluateEligibility(
          rule: rule,
          input: input,
        ),
      );

      final fullResult = _success(
        evaluator.evaluate(
          rule: rule,
          input: input,
        ),
      );

      expect(eligibility.isEligible, isTrue);
      expect(eligibility.eligibility, TriState.satisfied);
      expect(eligibility.confidence, RewardConfidence.confirmed);
      expect(eligibility.reasonCodes, isEmpty);

      expect(fullResult.points, isNull);
      expect(fullResult.confidence, RewardConfidence.unknown);
      expect(
        fullResult.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.periodStateMissing,
        ],
      );
    });

    test('preserves unavailable condition results without calculation', () {
      final conditionId = _id('condition_unknown');

      final result = _eligibilitySuccess(
        evaluator.evaluateEligibility(
          rule: _rule(
            conditionExpression: ConditionReferenceExpression(conditionId),
          ),
          input: _input(
            transactionDate: _date('2026-06-01'),
            conditionContext: ConditionEvaluationContext(
              states: <StableId, TriState>{
                conditionId: TriState.unknown,
              },
            ),
          ),
        ),
      );

      expect(result.isEligible, isFalse);
      expect(result.eligibility, TriState.unknown);
      expect(result.confidence, RewardConfidence.conditional);
      expect(
        result.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.conditionUnknown,
        ],
      );
    });
  });
  group('RewardRuleEvaluator period aggregation integration', () {
    // PR09_SLICE3A_TEST
    test('keeps transaction-scoped calculation behavior unchanged', () {
      final result = _success(
        evaluator.evaluate(
          rule: _rule(
            calculation: const FixedPointsRewardCalculation(PointAmount(25)),
            aggregation: _aggregation(
              scope: RewardAggregationScope.transaction,
              aggregationKey: null,
              incrementalAward: false,
            ),
          ),
          input: _input(
            transactionDate: _date('2026-06-01'),
          ),
        ),
      );

      expect(result.points, const PointAmount(25));
      expect(result.confidence, RewardConfidence.confirmed);
      expect(
        result.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.applied],
      );
    });

    // PR09_SLICE3A_TEST
    test('routes non-transaction scope to period aggregation', () {
      final key = _id('aggregation_one');

      final result = _success(
        evaluator.evaluate(
          rule: _rule(
            aggregation: _aggregation(
              scope: RewardAggregationScope.calendarMonth,
              aggregationKey: key,
            ),
          ),
          input: _input(
            transactionDate: _date('2026-06-01'),
            periodAggregationSnapshots: <StableId, PeriodAggregationSnapshot>{
              key: _periodSnapshot(),
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

    // PR09_SLICE3A_TEST
    test('preserves missing period state as unavailable', () {
      final result = _success(
        evaluator.evaluate(
          rule: _rule(
            aggregation: _aggregation(
              scope: RewardAggregationScope.calendarMonth,
              aggregationKey: _id('aggregation_one'),
            ),
          ),
          input: _input(
            transactionDate: _date('2026-06-01'),
          ),
        ),
      );

      expect(result.points, isNull);
      expect(result.eligibility, TriState.unknown);
      expect(result.confidence, RewardConfidence.unknown);
      expect(
        result.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.periodStateMissing,
        ],
      );
    });

    // PR09_SLICE3A_TEST
    test('propagates structured period configuration failures', () {
      final result = evaluator.evaluate(
        rule: _rule(
          aggregation: _aggregation(
            scope: RewardAggregationScope.calendarMonth,
            aggregationKey: _id('aggregation_one'),
            incrementalAward: false,
          ),
        ),
        input: _input(
          transactionDate: _date('2026-06-01'),
        ),
      );

      final error = _failure(result);

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.operation, 'periodAggregation.evaluate');
      expect(error.context['field'], 'aggregation.incrementalAward');
      expect(error.context['reason'], 'periodEndAwardNotImplemented');
    });

    // PR09_SLICE3A_TEST
    test('finishes eligibility checks before period evaluation', () {
      final result = _success(
        evaluator.evaluate(
          rule: _rule(
            selectors: _selectors(
              instrumentIds: <StableId>[_id('required_instrument')],
            ),
            aggregation: _aggregation(
              scope: RewardAggregationScope.calendarMonth,
              aggregationKey: null,
            ),
          ),
          input: _input(
            transactionDate: _date('2026-06-01'),
          ),
        ),
      );

      expect(result.eligibility, TriState.notSatisfied);
      expect(result.points, PointAmount.zero);
      expect(
        result.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.selectorMismatch,
        ],
      );
    });
  });
  group('RewardRuleEvaluator calculation integration', () {
    test('passes the threshold snapshot to calculation evaluation', () {
      final calculation = ThresholdBonusRewardCalculation(
        thresholdAmount: const MoneyYen(1000),
        bonusPoints: const PointAmount(100),
        maxAwardsPerPeriod: 1,
      );

      final unavailable = _success(
        evaluator.evaluate(
          rule: _rule(calculation: calculation),
          input: _input(
            amount: const MoneyYen(100),
            transactionDate: _date('2026-06-01'),
          ),
        ),
      );

      final calculated = _success(
        evaluator.evaluate(
          rule: _rule(calculation: calculation),
          input: _input(
            amount: const MoneyYen(100),
            transactionDate: _date('2026-06-01'),
            thresholdPeriodSnapshot: ThresholdPeriodSnapshot.validated(
              periodSpendBefore: const MoneyYen(900),
              awardsConsumed: 0,
            ),
          ),
        ),
      );

      expect(unavailable.points, isNull);
      expect(unavailable.confidence, RewardConfidence.unknown);
      expect(
        unavailable.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.periodStateMissing,
        ],
      );

      expect(calculated.points, const PointAmount(100));
      expect(calculated.confidence, RewardConfidence.confirmed);
      expect(
        calculated.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.applied],
      );
    });

    test('rejects a negative transaction amount at the rule boundary', () {
      final result = evaluator.evaluate(
        rule: _rule(),
        input: _input(
          amount: const MoneyYen(-1),
          transactionDate: _date('2026-06-01'),
        ),
      );

      final error = _failure(result);
      expect(error.code, AppErrorCode.calculationInputInvalid);
      expect(error.operation, 'rewardRule.evaluate');
      expect(error.context['field'], 'amount');
      expect(error.context['ruleId'], 'rule_one');
    });
  });
}

RewardRule _rule({
  SelectorSet? selectors,
  SelectorSet? exclusions,
  ConditionExpression? conditionExpression,
  RewardCalculation calculation =
      const FixedPointsRewardCalculation(PointAmount(25)),
  RewardAggregation? aggregation,
  ValidityPeriod validityPeriod = ValidityPeriod.unbounded,
  RewardDateBasis dateBasis = RewardDateBasis.transactionDate,
}) {
  return RewardRule(
    id: _id('rule_one'),
    name: 'Rule one',
    description: '',
    ruleKind: RewardRuleKind.baseReward,
    selectors: selectors ?? _selectors(),
    exclusions: exclusions ?? _selectors(),
    conditionExpression: conditionExpression,
    calculation: calculation,
    outputPointProgramId: null,
    aggregation: aggregation ??
        RewardAggregation(
          scope: RewardAggregationScope.transaction,
          aggregationKey: null,
          periodMinimumEligibleSpend: MoneyYen.zero,
          conditionEvaluationTiming: 'transaction',
          incrementalAward: false,
        ),
    stacking: RewardStacking(
      policy: 'stack',
      exclusiveGroupId: null,
      replacesRuleIds: const <StableId>[],
      suppressesRuleIds: const <StableId>[],
      suppressesTags: const <StableId>[],
      dependsOnRuleIds: const <StableId>[],
      applicationOrder: 0,
    ),
    cap: null,
    validityPeriod: validityPeriod,
    dateBasis: dateBasis,
    timezone: 'Asia/Tokyo',
    displayClaim: null,
    sourceIds: const <StableId>[],
    lastVerifiedAt: _date('2026-01-01'),
    status: CatalogItemStatus.active,
    priority: 0,
    tags: const <StableId>[],
    notes: const <String>[],
  );
}

SelectorSet _selectors({
  Iterable<StableId> instrumentIds = const <StableId>[],
  Iterable<StableId> modeIds = const <StableId>[],
  Iterable<StableId> routeIds = const <StableId>[],
  Iterable<StableId> fundingRelationIds = const <StableId>[],
  Iterable<StableId> merchantIds = const <StableId>[],
  Iterable<StableId> merchantGroupIds = const <StableId>[],
  Iterable<StableId> categoryIds = const <StableId>[],
  Iterable<StableId> brandIds = const <StableId>[],
  Iterable<StableId> locationIds = const <StableId>[],
  Iterable<StableId> transactionTags = const <StableId>[],
}) {
  return SelectorSet(
    instrumentIds: instrumentIds,
    modeIds: modeIds,
    routeIds: routeIds,
    fundingRelationIds: fundingRelationIds,
    merchantIds: merchantIds,
    merchantGroupIds: merchantGroupIds,
    categoryIds: categoryIds,
    brandIds: brandIds,
    locationIds: locationIds,
    transactionTags: transactionTags,
  );
}

RewardAggregation _aggregation({
  required RewardAggregationScope scope,
  required StableId? aggregationKey,
  bool incrementalAward = true,
}) {
  return RewardAggregation(
    scope: scope,
    aggregationKey: aggregationKey,
    periodMinimumEligibleSpend: MoneyYen.zero,
    conditionEvaluationTiming: 'transaction',
    incrementalAward: incrementalAward,
  );
}

PeriodAggregationSnapshot _periodSnapshot() {
  return PeriodAggregationSnapshot.validated(
    periodStart: _date('2026-06-01'),
    periodEndExclusive: _date('2026-07-01'),
    periodSpendBefore: const MoneyYen(1000),
    periodSpendAfter: const MoneyYen(1500),
    pointsBefore: const PointAmount(10),
    pointsAfter: const PointAmount(15),
    currentIncrement: const PointAmount(5),
    confidence: PeriodDataConfidence.exact,
  );
}

RewardEvaluationInput _populatedInput({
  CalculationDate? allDates,
}) {
  final date = allDates ?? _date('2026-06-01');

  return RewardEvaluationInput(
    amount: const MoneyYen(1000),
    instrumentId: _id('instrument_one'),
    modeId: _id('mode_one'),
    routeId: _id('route_one'),
    fundingRelationIds: <StableId>[_id('funding_one')],
    merchantId: _id('merchant_one'),
    merchantGroupIds: <StableId>[_id('merchant_group_one')],
    categoryIds: <StableId>[_id('category_one')],
    brandIds: <StableId>[_id('brand_one')],
    locationIds: <StableId>[_id('location_one')],
    transactionTags: <StableId>[_id('transaction_tag_one')],
    transactionDate: date,
    postingDate: date,
    settlementDataReceivedDate: date,
    billingDate: date,
    entryDate: date,
    campaignRegistrationDate: date,
    periodEndDate: date,
    conditionContext: ConditionEvaluationContext(),
  );
}

RewardEvaluationInput _input({
  MoneyYen amount = MoneyYen.zero,
  CalculationDate? transactionDate,
  ConditionEvaluationContext? conditionContext,
  ThresholdPeriodSnapshot? thresholdPeriodSnapshot,
  Map<StableId, PeriodAggregationSnapshot> periodAggregationSnapshots =
      const <StableId, PeriodAggregationSnapshot>{},
}) {
  return RewardEvaluationInput(
    amount: amount,
    instrumentId: null,
    modeId: null,
    routeId: null,
    merchantId: null,
    transactionDate: transactionDate,
    conditionContext: conditionContext ?? ConditionEvaluationContext(),
    thresholdPeriodSnapshot: thresholdPeriodSnapshot,
    periodAggregationSnapshots: periodAggregationSnapshots,
  );
}

RewardRuleEligibilityResult _eligibilitySuccess(
  AppResult<RewardRuleEligibilityResult> result,
) {
  expect(result, isA<AppSuccess<RewardRuleEligibilityResult>>());
  return (result as AppSuccess<RewardRuleEligibilityResult>).value;
}

RewardRuleEvaluationResult _success(
  AppResult<RewardRuleEvaluationResult> result,
) {
  expect(result, isA<AppSuccess<RewardRuleEvaluationResult>>());
  return (result as AppSuccess<RewardRuleEvaluationResult>).value;
}

AppError _failure(
  AppResult<RewardRuleEvaluationResult> result,
) {
  expect(result, isA<AppFailure<RewardRuleEvaluationResult>>());
  return (result as AppFailure<RewardRuleEvaluationResult>).error;
}

StableId _id(String value) {
  final result = StableId.create(value);
  expect(result, isA<AppSuccess<StableId>>());
  return (result as AppSuccess<StableId>).value;
}

CalculationDate _date(String value) {
  final result = CalculationDate.parse(value);
  expect(result, isA<AppSuccess<CalculationDate>>());
  return (result as AppSuccess<CalculationDate>).value;
}

ValidityPeriod _period(
  CalculationDate startsOn,
  CalculationDate endsBefore,
) {
  final result = ValidityPeriod.create(
    startsOn: startsOn,
    endsBefore: endsBefore,
  );
  expect(result, isA<AppSuccess<ValidityPeriod>>());
  return (result as AppSuccess<ValidityPeriod>).value;
}

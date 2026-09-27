import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/core/value_objects/validity_period.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/calculation/period_aggregation_snapshot.dart';
import 'package:bestpay/domain/calculation/reward_evaluation_input.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';
import 'package:bestpay/domain/calculation/reward_rule_evaluation_result.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_evaluation_result.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_evaluator.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_validator.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = RewardRuleSetValidator();
  const evaluator = RewardRuleSetEvaluator();

  group('period aggregation validation', () {
    // PR09_SLICE3C_VALIDATOR_TEST
    test('accepts every non-transaction scope with supported semantics', () {
      for (final scope in RewardAggregationScope.values.where(
        (value) => value != RewardAggregationScope.transaction,
      )) {
        final rules = _validated(
          validator.validateAndOrder(
            <RewardRule>[
              _rule(
                id: 'period_rule',
                aggregation: _periodAggregation(
                  key: _id('aggregation_one'),
                  scope: scope,
                  minimumSpend: const MoneyYen(1000),
                ),
              ),
            ],
          ),
        );

        expect(rules.single.aggregation.scope, scope);
      }
    });

    // PR09_SLICE3C_VALIDATOR_TEST
    test('requires an aggregation key for period scope', () {
      final error = _validationFailure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(
              id: 'period_rule',
              aggregation: _periodAggregation(key: null),
            ),
          ],
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['field'], 'aggregation.aggregationKey');
      expect(error.context['reason'], 'aggregationKeyRequired');
    });

    // PR09_SLICE3C_VALIDATOR_TEST
    test('requires incremental awards for period scope', () {
      final error = _validationFailure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(
              id: 'period_rule',
              aggregation: _periodAggregation(
                key: _id('aggregation_one'),
                incrementalAward: false,
              ),
            ),
          ],
        ),
      );

      expect(error.context['field'], 'aggregation.incrementalAward');
      expect(error.context['reason'], 'periodEndAwardNotImplemented');
    });

    // PR09_SLICE3C_VALIDATOR_TEST
    test('rejects unsupported period condition timing', () {
      final error = _validationFailure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(
              id: 'period_rule',
              aggregation: _periodAggregation(
                key: _id('aggregation_one'),
                conditionEvaluationTiming: 'periodEnd',
              ),
            ),
          ],
        ),
      );

      expect(error.context['field'], 'aggregation.conditionEvaluationTiming');
      expect(error.context['reason'], 'unsupportedConditionEvaluationTiming');
    });

    // PR09_SLICE3C_VALIDATOR_TEST
    test('rejects negative period minimum spend at the model boundary', () {
      expect(
        () => RewardAggregation(
          scope: RewardAggregationScope.calendarMonth,
          aggregationKey: _id('aggregation_one'),
          periodMinimumEligibleSpend: const MoneyYen(-1),
          conditionEvaluationTiming: 'transaction',
          incrementalAward: true,
        ),
        throwsArgumentError,
      );
    });

    // PR09_SLICE3C_VALIDATOR_TEST
    test('rejects mirrors involving period aggregation', () {
      final sourceId = _id('source_rule');

      final periodMirrorError = _validationFailure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(id: 'source_rule'),
            _rule(
              id: 'period_mirror',
              calculation: MirrorRewardCalculation(
                sourceRuleId: sourceId,
                multiplier: Rational.one,
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: true,
              ),
              aggregation: _periodAggregation(
                key: _id('mirror_aggregation'),
              ),
            ),
          ],
        ),
      );

      final periodSourceError = _validationFailure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(
              id: 'source_rule',
              aggregation: _periodAggregation(
                key: _id('source_aggregation'),
              ),
            ),
            _rule(
              id: 'transaction_mirror',
              calculation: MirrorRewardCalculation(
                sourceRuleId: sourceId,
                multiplier: Rational.one,
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: true,
              ),
            ),
          ],
        ),
      );

      for (final error in <AppError>[
        periodMirrorError,
        periodSourceError,
      ]) {
        expect(error.context['field'], 'calculation');
        expect(error.context['reason'], 'unsupportedPeriodMirror');
      }
    });
  });

  group('period aggregation rule-set orchestration', () {
    // PR09_SLICE3C_RULESET_TEST
    test('aggregates period points and projects period trace values', () {
      final key = _id('aggregation_one');
      final programId = _id('program_one');

      final result = _resultSuccess(
        evaluator.evaluateResult(
          rules: <RewardRule>[
            _rule(
              id: 'period_rule',
              outputPointProgramId: programId,
              aggregation: _periodAggregation(key: key),
            ),
          ],
          input: _input(
            snapshots: <StableId, PeriodAggregationSnapshot>{
              key: _snapshot(),
            },
          ),
        ),
      );

      expect(result.pointsByProgram[programId], const PointAmount(5));
      expect(result.ruleResults.single.points, const PointAmount(5));
      expect(result.trace.single.amountBefore, const MoneyYen(1000));
      expect(result.trace.single.amountAfter, const MoneyYen(1500));
      expect(result.trace.single.details['aggregationKey'], 'aggregation_one');
      expect(result.trace.single.details['periodStart'], '2026-06-01');
      expect(
        result.trace.single.details['periodEndExclusive'],
        '2026-07-01',
      );
    });

    // PR09_SLICE3C_RULESET_TEST
    test('uses period points in exclusive-group comparison', () {
      final key = _id('aggregation_one');
      final groupId = _id('exclusive_group');

      final results = _evaluated(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(
              id: 'transaction_rule',
              calculation: const FixedPointsRewardCalculation(PointAmount(10)),
              stacking: _stacking(exclusiveGroupId: groupId),
            ),
            _rule(
              id: 'period_rule',
              aggregation: _periodAggregation(key: key),
              stacking: _stacking(exclusiveGroupId: groupId),
            ),
          ],
          input: _input(
            snapshots: <StableId, PeriodAggregationSnapshot>{
              key: _snapshot(
                pointsAfter: const PointAmount(30),
                currentIncrement: const PointAmount(20),
              ),
            },
          ),
        ),
      );

      final byId = _byId(results);

      expect(byId['period_rule']!.points, const PointAmount(20));
      expect(
        byId['transaction_rule']!.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.exclusiveGroupLost,
        ],
      );
    });

    // PR09_SLICE3C_RULESET_TEST
    test('allows an eligible period rule to replace a target', () {
      final key = _id('aggregation_one');
      final targetId = _id('target_rule');

      final results = _evaluated(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(id: 'target_rule'),
            _rule(
              id: 'period_controller',
              aggregation: _periodAggregation(key: key),
              stacking: _stacking(
                replacesRuleIds: <StableId>[targetId],
              ),
            ),
          ],
          input: _input(
            snapshots: <StableId, PeriodAggregationSnapshot>{
              key: _snapshot(),
            },
          ),
        ),
      );

      final byId = _byId(results);

      expect(
        byId['target_rule']!.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.replaced],
      );
      expect(
        byId['period_controller']!.points,
        const PointAmount(5),
      );
    });

    // PR09_SLICE3C_RULESET_TEST
    test('allows an eligible period rule to suppress a target', () {
      final key = _id('aggregation_one');
      final targetId = _id('target_rule');

      final results = _evaluated(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(id: 'target_rule'),
            _rule(
              id: 'period_controller',
              aggregation: _periodAggregation(key: key),
              stacking: _stacking(
                suppressesRuleIds: <StableId>[targetId],
              ),
            ),
          ],
          input: _input(
            snapshots: <StableId, PeriodAggregationSnapshot>{
              key: _snapshot(),
            },
          ),
        ),
      );

      expect(
        _byId(results)['target_rule']!.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.suppressed],
      );
    });

    // PR09_SLICE3C_RULESET_TEST
    test('keeps a dependent rule when its period prerequisite is eligible', () {
      final key = _id('aggregation_one');
      final prerequisiteId = _id('period_prerequisite');

      final results = _evaluated(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(
              id: 'period_prerequisite',
              aggregation: _periodAggregation(key: key),
            ),
            _rule(
              id: 'dependent_rule',
              stacking: _stacking(
                dependsOnRuleIds: <StableId>[prerequisiteId],
              ),
            ),
          ],
          input: _input(
            snapshots: <StableId, PeriodAggregationSnapshot>{
              key: _snapshot(),
            },
          ),
        ),
      );

      final byId = _byId(results);

      expect(
        byId['period_prerequisite']!.points,
        const PointAmount(5),
      );
      expect(
        byId['dependent_rule']!.points,
        const PointAmount(10),
      );
    });

    // PR09_SLICE3C_RULESET_TEST
    test('missing period state does not deactivate an eligible replacer', () {
      final targetId = _id('target_rule');

      final results = _evaluated(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(id: 'target_rule'),
            _rule(
              id: 'period_controller',
              aggregation: _periodAggregation(
                key: _id('aggregation_one'),
              ),
              stacking: _stacking(
                replacesRuleIds: <StableId>[targetId],
              ),
            ),
          ],
          input: _input(),
        ),
      );

      final byId = _byId(results);

      expect(
        byId['target_rule']!.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.replaced],
      );
      expect(byId['period_controller']!.eligibility, TriState.unknown);
      expect(byId['period_controller']!.points, isNull);
      expect(
        byId['period_controller']!.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.periodStateMissing,
        ],
      );
    });

    // PR09_SLICE3C_RULESET_TEST
    test('unknown period state does not deactivate an eligible suppressor', () {
      final key = _id('aggregation_one');
      final targetId = _id('target_rule');

      final results = _evaluated(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(id: 'target_rule'),
            _rule(
              id: 'period_controller',
              aggregation: _periodAggregation(key: key),
              stacking: _stacking(
                suppressesRuleIds: <StableId>[targetId],
              ),
            ),
          ],
          input: _input(
            snapshots: <StableId, PeriodAggregationSnapshot>{
              key: _snapshot(
                confidence: PeriodDataConfidence.unknown,
              ),
            },
          ),
        ),
      );

      final byId = _byId(results);

      expect(
        byId['target_rule']!.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.suppressed],
      );
      expect(byId['period_controller']!.eligibility, TriState.unknown);
      expect(byId['period_controller']!.points, isNull);
      expect(
        byId['period_controller']!.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.periodStateUnknown,
        ],
      );
    });

    // PR09_SLICE3C_RULESET_TEST
    test('missing period state still satisfies an eligible dependency', () {
      final prerequisiteId = _id('period_prerequisite');

      final results = _evaluated(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(
              id: 'period_prerequisite',
              aggregation: _periodAggregation(
                key: _id('aggregation_one'),
              ),
            ),
            _rule(
              id: 'dependent_rule',
              stacking: _stacking(
                dependsOnRuleIds: <StableId>[prerequisiteId],
              ),
            ),
          ],
          input: _input(),
        ),
      );

      final byId = _byId(results);

      expect(
        byId['period_prerequisite']!.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.periodStateMissing,
        ],
      );
      expect(byId['period_prerequisite']!.points, isNull);
      expect(
        byId['dependent_rule']!.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.applied],
      );
      expect(byId['dependent_rule']!.points, const PointAmount(10));
    });

    // PR09_SLICE3C_RULESET_TEST
    test('does not select a winner with missing period state', () {
      final groupId = _id('exclusive_group');

      final results = _evaluated(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(
              id: 'transaction_rule',
              stacking: _stacking(exclusiveGroupId: groupId),
            ),
            _rule(
              id: 'period_rule',
              aggregation: _periodAggregation(
                key: _id('aggregation_one'),
              ),
              stacking: _stacking(exclusiveGroupId: groupId),
            ),
          ],
          input: _input(),
        ),
      );

      final byId = _byId(results);

      expect(
        byId['transaction_rule']!.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.applied],
      );
      expect(byId['period_rule']!.eligibility, TriState.unknown);
      expect(byId['period_rule']!.points, isNull);
      expect(
        byId['period_rule']!.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.periodStateMissing,
        ],
      );
    });
  });
}

RewardRule _rule({
  required String id,
  StableId? outputPointProgramId,
  RewardCalculation calculation =
      const FixedPointsRewardCalculation(PointAmount(10)),
  RewardAggregation? aggregation,
  RewardStacking? stacking,
}) {
  return RewardRule(
    id: _id(id),
    name: id,
    description: '',
    ruleKind: RewardRuleKind.baseReward,
    selectors: _selectors(),
    exclusions: _selectors(),
    conditionExpression: null,
    calculation: calculation,
    outputPointProgramId: outputPointProgramId,
    aggregation: aggregation ??
        RewardAggregation(
          scope: RewardAggregationScope.transaction,
          aggregationKey: null,
          periodMinimumEligibleSpend: MoneyYen.zero,
          conditionEvaluationTiming: 'transaction',
          incrementalAward: false,
        ),
    stacking: stacking ?? _stacking(),
    cap: null,
    validityPeriod: ValidityPeriod.unbounded,
    dateBasis: RewardDateBasis.transactionDate,
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

RewardAggregation _periodAggregation({
  required StableId? key,
  RewardAggregationScope scope = RewardAggregationScope.calendarMonth,
  MoneyYen minimumSpend = MoneyYen.zero,
  String conditionEvaluationTiming = 'transaction',
  bool incrementalAward = true,
}) {
  return RewardAggregation(
    scope: scope,
    aggregationKey: key,
    periodMinimumEligibleSpend: minimumSpend,
    conditionEvaluationTiming: conditionEvaluationTiming,
    incrementalAward: incrementalAward,
  );
}

RewardStacking _stacking({
  Iterable<StableId> replacesRuleIds = const <StableId>[],
  Iterable<StableId> suppressesRuleIds = const <StableId>[],
  Iterable<StableId> dependsOnRuleIds = const <StableId>[],
  StableId? exclusiveGroupId,
}) {
  return RewardStacking(
    policy: 'stack',
    exclusiveGroupId: exclusiveGroupId,
    replacesRuleIds: replacesRuleIds,
    suppressesRuleIds: suppressesRuleIds,
    suppressesTags: const <StableId>[],
    dependsOnRuleIds: dependsOnRuleIds,
    applicationOrder: 0,
  );
}

SelectorSet _selectors() {
  return SelectorSet(
    instrumentIds: const <StableId>[],
    modeIds: const <StableId>[],
    routeIds: const <StableId>[],
    fundingRelationIds: const <StableId>[],
    merchantIds: const <StableId>[],
    merchantGroupIds: const <StableId>[],
    categoryIds: const <StableId>[],
    brandIds: const <StableId>[],
    locationIds: const <StableId>[],
    transactionTags: const <StableId>[],
  );
}

RewardEvaluationInput _input({
  Map<StableId, PeriodAggregationSnapshot> snapshots =
      const <StableId, PeriodAggregationSnapshot>{},
}) {
  return RewardEvaluationInput(
    amount: const MoneyYen(100),
    instrumentId: null,
    modeId: null,
    routeId: null,
    merchantId: null,
    transactionDate: _date('2026-06-15'),
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

List<RewardRule> _validated(
  AppResult<List<RewardRule>> result,
) {
  expect(result, isA<AppSuccess<List<RewardRule>>>());
  return (result as AppSuccess<List<RewardRule>>).value;
}

AppError _validationFailure(
  AppResult<List<RewardRule>> result,
) {
  expect(result, isA<AppFailure<List<RewardRule>>>());
  return (result as AppFailure<List<RewardRule>>).error;
}

List<RewardRuleEvaluationResult> _evaluated(
  AppResult<List<RewardRuleEvaluationResult>> result,
) {
  expect(result, isA<AppSuccess<List<RewardRuleEvaluationResult>>>());
  return (result as AppSuccess<List<RewardRuleEvaluationResult>>).value;
}

RewardRuleSetEvaluationResult _resultSuccess(
  AppResult<RewardRuleSetEvaluationResult> result,
) {
  expect(result, isA<AppSuccess<RewardRuleSetEvaluationResult>>());
  return (result as AppSuccess<RewardRuleSetEvaluationResult>).value;
}

Map<String, RewardRuleEvaluationResult> _byId(
  List<RewardRuleEvaluationResult> results,
) {
  return <String, RewardRuleEvaluationResult>{
    for (final result in results) result.ruleId.value: result,
  };
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

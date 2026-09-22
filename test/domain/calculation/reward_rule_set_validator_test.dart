import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/validity_period.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_validator.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RewardRuleSetValidator ordering', () {
    test('orders independently of input order', () {
      const validator = RewardRuleSetValidator();

      final ruleA = _rule(
        id: 'rule_a',
        applicationOrder: 1,
        priority: 100,
      );
      final ruleB = _rule(
        id: 'rule_b',
        applicationOrder: 0,
        priority: 10,
      );
      final ruleC = _rule(
        id: 'rule_c',
        applicationOrder: 0,
        priority: 20,
      );
      final ruleD = _rule(
        id: 'rule_d',
        applicationOrder: 0,
        priority: 20,
      );

      final first = _success(
        validator.validateAndOrder(
          <RewardRule>[ruleA, ruleB, ruleC, ruleD],
        ),
      );
      final second = _success(
        validator.validateAndOrder(
          <RewardRule>[ruleD, ruleC, ruleB, ruleA],
        ),
      );

      final expected = <String>[
        'rule_c',
        'rule_d',
        'rule_b',
        'rule_a',
      ];

      expect(first.map((rule) => rule.id.value), expected);
      expect(second.map((rule) => rule.id.value), expected);
      expect(
        () => first.add(_rule(id: 'rule_new')),
        throwsUnsupportedError,
      );
    });
  });

  group('RewardRuleSetValidator limits', () {
    test('rejects a rule-count limit violation', () {
      const validator = RewardRuleSetValidator(
        maximumRuleCount: 2,
      );

      final error = _failure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(id: 'rule_one'),
            _rule(id: 'rule_two'),
            _rule(id: 'rule_three'),
          ],
        ),
      );

      expect(error.code, AppErrorCode.calculationOverflow);
      expect(error.context['reason'], 'ruleLimitExceeded');
      expect(error.context['limit'], 2);
    });

    test('rejects selector and relation ID limit violations', () {
      const validator = RewardRuleSetValidator(
        maximumIdsPerAxis: 1,
      );

      final selectorError = _failure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(
              id: 'rule_selector',
              selectors: _selectors(
                instrumentIds: <StableId>[
                  _id('instrument_one'),
                  _id('instrument_two'),
                ],
              ),
            ),
          ],
        ),
      );

      final relationError = _failure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(
              id: 'rule_relation',
              stacking: _stacking(
                suppressesTags: <StableId>[
                  _id('tag_one'),
                  _id('tag_two'),
                ],
              ),
            ),
          ],
        ),
      );

      expect(
        selectorError.code,
        AppErrorCode.calculationOverflow,
      );
      expect(
        selectorError.context['reason'],
        'selectorIdLimitExceeded',
      );
      expect(
        selectorError.context['field'],
        'selectors.instrumentIds',
      );

      expect(
        relationError.code,
        AppErrorCode.calculationOverflow,
      );
      expect(
        relationError.context['reason'],
        'relationIdLimitExceeded',
      );
      expect(relationError.context['field'], 'suppressesTags');
    });
  });

  group('RewardRuleSetValidator references', () {
    test('rejects duplicate rule IDs', () {
      const validator = RewardRuleSetValidator();

      final error = _failure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(id: 'same_rule'),
            _rule(id: 'same_rule'),
          ],
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['reason'], 'duplicateRuleId');
      expect(error.context['ruleId'], 'same_rule');
    });

    test('rejects missing relationship targets', () {
      const validator = RewardRuleSetValidator();
      final missing = _id('missing_rule');

      final cases = <({RewardRule rule, String field})>[
        (
          rule: _rule(
            id: 'replace_rule',
            stacking: _stacking(
              replacesRuleIds: <StableId>[missing],
            ),
          ),
          field: 'replacesRuleIds',
        ),
        (
          rule: _rule(
            id: 'suppress_rule',
            stacking: _stacking(
              suppressesRuleIds: <StableId>[missing],
            ),
          ),
          field: 'suppressesRuleIds',
        ),
        (
          rule: _rule(
            id: 'depend_rule',
            stacking: _stacking(
              dependsOnRuleIds: <StableId>[missing],
            ),
          ),
          field: 'dependsOnRuleIds',
        ),
        (
          rule: _rule(
            id: 'mirror_rule',
            calculation: MirrorRewardCalculation(
              sourceRuleId: missing,
              multiplier: Rational.one,
              inheritEligibility: false,
              inheritExclusions: false,
              useFinalSourceAmount: true,
            ),
          ),
          field: 'calculation.sourceRuleId',
        ),
      ];

      for (final testCase in cases) {
        final error = _failure(
          validator.validateAndOrder(
            <RewardRule>[testCase.rule],
          ),
        );

        expect(error.code, AppErrorCode.calculationRuleInvalid);
        expect(error.context['reason'], 'referencedRuleMissing');
        expect(error.context['field'], testCase.field);
        expect(error.context['referenceRuleId'], 'missing_rule');
      }
    });

    test('rejects self replacement, suppression, and dependency', () {
      const validator = RewardRuleSetValidator();
      final self = _id('self_rule');

      final cases = <({RewardRule rule, String reason})>[
        (
          rule: _rule(
            id: 'self_rule',
            stacking: _stacking(
              replacesRuleIds: <StableId>[self],
            ),
          ),
          reason: 'selfReplacement',
        ),
        (
          rule: _rule(
            id: 'self_rule',
            stacking: _stacking(
              suppressesRuleIds: <StableId>[self],
            ),
          ),
          reason: 'selfSuppression',
        ),
        (
          rule: _rule(
            id: 'self_rule',
            stacking: _stacking(
              dependsOnRuleIds: <StableId>[self],
            ),
          ),
          reason: 'dependencyCycle',
        ),
      ];

      for (final testCase in cases) {
        final error = _failure(
          validator.validateAndOrder(
            <RewardRule>[testCase.rule],
          ),
        );

        expect(error.code, AppErrorCode.calculationRuleInvalid);
        expect(error.context['reason'], testCase.reason);
      }
    });

    test('rejects relationship and mirror cycles', () {
      const validator = RewardRuleSetValidator();
      final ruleAId = _id('rule_a');
      final ruleBId = _id('rule_b');

      final replacementError = _failure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(
              id: 'rule_a',
              stacking: _stacking(
                replacesRuleIds: <StableId>[ruleBId],
              ),
            ),
            _rule(
              id: 'rule_b',
              stacking: _stacking(
                replacesRuleIds: <StableId>[ruleAId],
              ),
            ),
          ],
        ),
      );

      final dependencyError = _failure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(
              id: 'rule_a',
              stacking: _stacking(
                dependsOnRuleIds: <StableId>[ruleBId],
              ),
            ),
            _rule(
              id: 'rule_b',
              stacking: _stacking(
                dependsOnRuleIds: <StableId>[ruleAId],
              ),
            ),
          ],
        ),
      );

      final mirrorError = _failure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(
              id: 'rule_a',
              calculation: MirrorRewardCalculation(
                sourceRuleId: ruleBId,
                multiplier: Rational.one,
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: true,
              ),
            ),
            _rule(
              id: 'rule_b',
              calculation: MirrorRewardCalculation(
                sourceRuleId: ruleAId,
                multiplier: Rational.one,
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: true,
              ),
            ),
          ],
        ),
      );

      expect(
        replacementError.context['reason'],
        'replacementCycle',
      );
      expect(
        dependencyError.context['reason'],
        'dependencyCycle',
      );
      expect(mirrorError.context['reason'], 'mirrorCycle');
    });

    test('rejects non-transaction aggregation scope', () {
      const validator = RewardRuleSetValidator();

      final error = _failure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(
              id: 'period_rule',
              aggregation: RewardAggregation(
                scope: RewardAggregationScope.calendarMonth,
                aggregationKey: null,
                periodMinimumEligibleSpend: MoneyYen.zero,
                conditionEvaluationTiming: 'transaction',
                incrementalAward: false,
              ),
            ),
          ],
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['field'], 'aggregation.scope');
      expect(error.context['reason'], 'unsupportedAggregationScope');
    });

    test('rejects incremental awards until period evaluation is implemented',
        () {
      const validator = RewardRuleSetValidator();

      final error = _failure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(
              id: 'incremental_rule',
              aggregation: RewardAggregation(
                scope: RewardAggregationScope.transaction,
                aggregationKey: null,
                periodMinimumEligibleSpend: MoneyYen.zero,
                conditionEvaluationTiming: 'transaction',
                incrementalAward: true,
              ),
            ),
          ],
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['field'], 'aggregation.incrementalAward');
      expect(error.context['reason'], 'unsupportedIncrementalAward');
    });
    test('rejects caps until supported values are specified', () {
      const validator = RewardRuleSetValidator();

      final error = _failure(
        validator.validateAndOrder(
          <RewardRule>[
            _rule(
              id: 'capped_rule',
              cap: RewardCap(
                capType: 'points',
                limit: 100,
                periodType: 'transaction',
                scopeKey: null,
                appliesTo: 'rule',
                overflowPolicy: 'truncate',
              ),
            ),
          ],
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['reason'], 'unsupportedCap');
      expect(error.context['field'], 'cap');
    });
  });

  test('rejects a suppression cycle', () {
    final firstId = _id('first_rule');
    final secondId = _id('second_rule');

    final error = _failure(
      RewardRuleSetValidator().validateAndOrder(<RewardRule>[
        _rule(
          id: 'first_rule',
          stacking: _stacking(
            suppressesRuleIds: <StableId>[secondId],
          ),
        ),
        _rule(
          id: 'second_rule',
          stacking: _stacking(
            suppressesRuleIds: <StableId>[firstId],
          ),
        ),
      ]),
    );

    expect(error.code, AppErrorCode.calculationRuleInvalid);
    expect(error.context['reason'], 'suppressionCycle');
  });

  test('rejects self suppression through a tag', () {
    final sharedTag = _id('shared_tag');

    final error = _failure(
      RewardRuleSetValidator().validateAndOrder(<RewardRule>[
        _rule(
          id: 'tagged_rule',
          tags: <StableId>[sharedTag],
          stacking: _stacking(
            suppressesTags: <StableId>[sharedTag],
          ),
        ),
      ]),
    );

    expect(error.code, AppErrorCode.calculationRuleInvalid);
    expect(error.context['reason'], 'suppressionCycle');
  });
}

RewardRule _rule({
  List<StableId> tags = const <StableId>[],
  required String id,
  SelectorSet? selectors,
  RewardStacking? stacking,
  RewardCalculation calculation =
      const FixedPointsRewardCalculation(PointAmount(1)),
  RewardAggregation? aggregation,
  RewardCap? cap,
  int applicationOrder = 0,
  int priority = 0,
}) {
  return RewardRule(
    id: _id(id),
    name: id,
    description: '',
    ruleKind: RewardRuleKind.baseReward,
    selectors: selectors ?? _selectors(),
    exclusions: _selectors(),
    conditionExpression: null,
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
    stacking: stacking ?? _stacking(applicationOrder: applicationOrder),
    cap: cap,
    validityPeriod: ValidityPeriod.unbounded,
    dateBasis: RewardDateBasis.transactionDate,
    timezone: 'Asia/Tokyo',
    displayClaim: null,
    sourceIds: const <StableId>[],
    lastVerifiedAt: _date('2026-01-01'),
    status: CatalogItemStatus.active,
    priority: priority,
    tags: tags,
    notes: const <String>[],
  );
}

RewardStacking _stacking({
  Iterable<StableId> replacesRuleIds = const <StableId>[],
  Iterable<StableId> suppressesRuleIds = const <StableId>[],
  Iterable<StableId> suppressesTags = const <StableId>[],
  Iterable<StableId> dependsOnRuleIds = const <StableId>[],
  int applicationOrder = 0,
}) {
  return RewardStacking(
    policy: 'stack',
    exclusiveGroupId: null,
    replacesRuleIds: replacesRuleIds,
    suppressesRuleIds: suppressesRuleIds,
    suppressesTags: suppressesTags,
    dependsOnRuleIds: dependsOnRuleIds,
    applicationOrder: applicationOrder,
  );
}

SelectorSet _selectors({
  Iterable<StableId> instrumentIds = const <StableId>[],
}) {
  return SelectorSet(
    instrumentIds: instrumentIds,
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

List<RewardRule> _success(
  AppResult<List<RewardRule>> result,
) {
  expect(result, isA<AppSuccess<List<RewardRule>>>());
  return (result as AppSuccess<List<RewardRule>>).value;
}

AppError _failure(
  AppResult<List<RewardRule>> result,
) {
  expect(result, isA<AppFailure<List<RewardRule>>>());
  return (result as AppFailure<List<RewardRule>>).error;
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

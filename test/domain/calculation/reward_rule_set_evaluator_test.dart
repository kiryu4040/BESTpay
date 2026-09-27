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
import 'package:bestpay/domain/calculation/reward_evaluation_input.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';
import 'package:bestpay/domain/calculation/reward_rule_evaluation_result.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_evaluation_result.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_evaluator.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = RewardRuleSetEvaluator();

  test('replaces a target without executing its calculation', () {
    final targetId = _id('target_rule');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'target_rule',
            calculation: ThresholdBonusRewardCalculation(
              thresholdAmount: const MoneyYen(1000),
              bonusPoints: const PointAmount(100),
              maxAwardsPerPeriod: 1,
            ),
          ),
          _rule(
            id: 'replacement_rule',
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
      byId['replacement_rule']!.points,
      const PointAmount(10),
    );
    expect(byId['target_rule']!.points, PointAmount.zero);
    expect(
      byId['target_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.replaced],
    );
  });

  test('explicit exclusion takes priority over replacement', () {
    final targetId = _id('target_rule');
    final excludedMerchant = _id('excluded_merchant');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'replacement_rule',
            stacking: _stacking(
              replacesRuleIds: <StableId>[targetId],
            ),
          ),
          _rule(
            id: 'target_rule',
            exclusions: _selectors(
              merchantIds: <StableId>[excludedMerchant],
            ),
          ),
        ],
        input: _input(merchantId: excludedMerchant),
      ),
    );

    final target = _byId(results)['target_rule']!;

    expect(target.eligibility, TriState.notSatisfied);
    expect(
      target.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.excluded],
    );
  });

  test('suppresses by rule ID and tag without calculating targets', () {
    final firstTargetId = _id('first_target');
    final suppressedTag = _id('suppressed_tag');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'suppression_rule',
            stacking: _stacking(
              suppressesRuleIds: <StableId>[firstTargetId],
              suppressesTags: <StableId>[suppressedTag],
            ),
          ),
          _rule(
            id: 'first_target',
            calculation: ThresholdBonusRewardCalculation(
              thresholdAmount: const MoneyYen(1000),
              bonusPoints: const PointAmount(100),
              maxAwardsPerPeriod: 1,
            ),
          ),
          _rule(
            id: 'second_target',
            tags: <StableId>[suppressedTag],
            calculation: ThresholdBonusRewardCalculation(
              thresholdAmount: const MoneyYen(1000),
              bonusPoints: const PointAmount(100),
              maxAwardsPerPeriod: 1,
            ),
          ),
        ],
        input: _input(),
      ),
    );

    final byId = _byId(results);

    for (final id in <String>['first_target', 'second_target']) {
      expect(byId[id]!.points, PointAmount.zero);
      expect(
        byId[id]!.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.suppressed],
      );
    }
  });

  test('an ineligible controller does not replace its target', () {
    final targetId = _id('target_rule');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'replacement_rule',
            selectors: _selectors(
              instrumentIds: <StableId>[_id('required_instrument')],
            ),
            stacking: _stacking(
              replacesRuleIds: <StableId>[targetId],
            ),
          ),
          _rule(id: 'target_rule'),
        ],
        input: _input(),
      ),
    );

    final byId = _byId(results);

    expect(
      byId['replacement_rule']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.selectorMismatch,
      ],
    );
    expect(byId['target_rule']!.points, const PointAmount(10));
    expect(
      byId['target_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.applied],
    );
  });

  test('replacement takes priority over suppression', () {
    final targetId = _id('target_rule');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'replacement_rule',
            applicationOrder: 0,
            stacking: _stacking(
              applicationOrder: 0,
              replacesRuleIds: <StableId>[targetId],
            ),
          ),
          _rule(
            id: 'suppression_rule',
            applicationOrder: 1,
            stacking: _stacking(
              applicationOrder: 1,
              suppressesRuleIds: <StableId>[targetId],
            ),
          ),
          _rule(id: 'target_rule'),
        ],
        input: _input(),
      ),
    );

    expect(
      _byId(results)['target_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.replaced],
    );
  });

  test('a replaced controller does not replace its target', () {
    final controllerId = _id('controller_rule');
    final targetId = _id('target_rule');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'controller_rule',
            stacking: _stacking(
              applicationOrder: 0,
              replacesRuleIds: <StableId>[targetId],
            ),
          ),
          _rule(
            id: 'root_rule',
            stacking: _stacking(
              applicationOrder: 1,
              replacesRuleIds: <StableId>[controllerId],
            ),
          ),
          _rule(
            id: 'target_rule',
            applicationOrder: 2,
          ),
        ],
        input: _input(),
      ),
    );

    final byId = _byId(results);

    expect(
      byId['controller_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.replaced],
    );
    expect(
      byId['target_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.applied],
    );
  });

  test('a suppressed controller does not suppress its target', () {
    final controllerId = _id('controller_rule');
    final targetId = _id('target_rule');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'controller_rule',
            stacking: _stacking(
              applicationOrder: 0,
              suppressesRuleIds: <StableId>[targetId],
            ),
          ),
          _rule(
            id: 'root_rule',
            stacking: _stacking(
              applicationOrder: 1,
              suppressesRuleIds: <StableId>[controllerId],
            ),
          ),
          _rule(
            id: 'target_rule',
            applicationOrder: 2,
          ),
        ],
        input: _input(),
      ),
    );

    final byId = _byId(results);

    expect(
      byId['controller_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.suppressed],
    );
    expect(
      byId['target_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.applied],
    );
  });
  test('keeps a rule when all dependencies are eligible', () {
    final prerequisiteId = _id('prerequisite_rule');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(id: 'prerequisite_rule'),
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
      byId['prerequisite_rule']!.points,
      const PointAmount(10),
    );
    expect(
      byId['dependent_rule']!.points,
      const PointAmount(10),
    );
    expect(
      byId['dependent_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.applied],
    );
  });

  test('rejects a dependency on an ineligible rule', () {
    final prerequisiteId = _id('prerequisite_rule');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'prerequisite_rule',
            selectors: _selectors(
              instrumentIds: <StableId>[
                _id('required_instrument'),
              ],
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
      byId['prerequisite_rule']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.selectorMismatch,
      ],
    );
    expect(
      byId['dependent_rule']!.points,
      PointAmount.zero,
    );
    expect(
      byId['dependent_rule']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.dependencyNotSatisfied,
      ],
    );
  });

  test('propagates dependency failure through a chain', () {
    final ruleBId = _id('rule_b');
    final ruleCId = _id('rule_c');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'rule_a',
            stacking: _stacking(
              dependsOnRuleIds: <StableId>[ruleBId],
            ),
          ),
          _rule(
            id: 'rule_b',
            stacking: _stacking(
              dependsOnRuleIds: <StableId>[ruleCId],
            ),
          ),
          _rule(
            id: 'rule_c',
            selectors: _selectors(
              instrumentIds: <StableId>[
                _id('missing_instrument'),
              ],
            ),
          ),
        ],
        input: _input(),
      ),
    );

    final byId = _byId(results);

    expect(
      byId['rule_c']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.selectorMismatch,
      ],
    );

    for (final id in <String>['rule_a', 'rule_b']) {
      expect(byId[id]!.points, PointAmount.zero);
      expect(
        byId[id]!.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.dependencyNotSatisfied,
        ],
      );
    }
  });

  test('fails a dependency whose target was suppressed', () {
    final prerequisiteId = _id('prerequisite_rule');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'suppression_rule',
            stacking: _stacking(
              suppressesRuleIds: <StableId>[prerequisiteId],
            ),
          ),
          _rule(id: 'prerequisite_rule'),
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
      byId['prerequisite_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.suppressed],
    );
    expect(
      byId['dependent_rule']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.dependencyNotSatisfied,
      ],
    );
  });
  test('exclusive group selects the highest-point rule', () {
    final groupId = _id('exclusive_group');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'lower_rule',
            calculation: const FixedPointsRewardCalculation(PointAmount(50)),
            stacking: _stacking(exclusiveGroupId: groupId),
          ),
          _rule(
            id: 'higher_rule',
            calculation: const FixedPointsRewardCalculation(PointAmount(100)),
            stacking: _stacking(exclusiveGroupId: groupId),
          ),
        ],
        input: _input(),
      ),
    );

    final byId = _byId(results);

    expect(byId['higher_rule']!.points, const PointAmount(100));
    expect(
      byId['higher_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.applied],
    );
    expect(byId['lower_rule']!.points, PointAmount.zero);
    expect(
      byId['lower_rule']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.exclusiveGroupLost,
      ],
    );
  });

  test('exclusive group uses priority before application order', () {
    final groupId = _id('exclusive_group');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'earlier_rule',
            priority: 10,
            stacking: _stacking(
              exclusiveGroupId: groupId,
              applicationOrder: 0,
            ),
          ),
          _rule(
            id: 'priority_rule',
            priority: 20,
            stacking: _stacking(
              exclusiveGroupId: groupId,
              applicationOrder: 10,
            ),
          ),
        ],
        input: _input(),
      ),
    );

    final byId = _byId(results);

    expect(
      byId['priority_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.applied],
    );
    expect(
      byId['earlier_rule']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.exclusiveGroupLost,
      ],
    );
  });

  test('exclusive group uses application order then rule ID for ties', () {
    final firstGroupId = _id('first_group');
    final secondGroupId = _id('second_group');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'later_rule',
            stacking: _stacking(
              exclusiveGroupId: firstGroupId,
              applicationOrder: 2,
            ),
          ),
          _rule(
            id: 'earlier_rule',
            stacking: _stacking(
              exclusiveGroupId: firstGroupId,
              applicationOrder: 1,
            ),
          ),
          _rule(
            id: 'rule_b',
            stacking: _stacking(
              exclusiveGroupId: secondGroupId,
            ),
          ),
          _rule(
            id: 'rule_a',
            stacking: _stacking(
              exclusiveGroupId: secondGroupId,
            ),
          ),
        ],
        input: _input(),
      ),
    );

    final byId = _byId(results);

    expect(
      byId['earlier_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.applied],
    );
    expect(
      byId['later_rule']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.exclusiveGroupLost,
      ],
    );
    expect(
      byId['rule_a']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.applied],
    );
    expect(
      byId['rule_b']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.exclusiveGroupLost,
      ],
    );
  });

  test('ineligible rules do not compete in an exclusive group', () {
    final groupId = _id('exclusive_group');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'ineligible_rule',
            calculation: const FixedPointsRewardCalculation(PointAmount(100)),
            selectors: _selectors(
              instrumentIds: <StableId>[
                _id('required_instrument'),
              ],
            ),
            stacking: _stacking(exclusiveGroupId: groupId),
          ),
          _rule(
            id: 'eligible_rule',
            calculation: const FixedPointsRewardCalculation(PointAmount(10)),
            stacking: _stacking(exclusiveGroupId: groupId),
          ),
        ],
        input: _input(),
      ),
    );

    final byId = _byId(results);

    expect(
      byId['ineligible_rule']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.selectorMismatch,
      ],
    );
    expect(byId['eligible_rule']!.points, const PointAmount(10));
  });

  test('does not choose a winner while a group calculation is unknown', () {
    final groupId = _id('exclusive_group');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'known_rule',
            calculation: const FixedPointsRewardCalculation(PointAmount(10)),
            stacking: _stacking(exclusiveGroupId: groupId),
          ),
          _rule(
            id: 'unknown_rule',
            calculation: ThresholdBonusRewardCalculation(
              thresholdAmount: const MoneyYen(1000),
              bonusPoints: const PointAmount(100),
              maxAwardsPerPeriod: 1,
            ),
            stacking: _stacking(exclusiveGroupId: groupId),
          ),
        ],
        input: _input(),
      ),
    );

    final byId = _byId(results);

    expect(
      byId['known_rule']!.reasonCodes,
      const <RewardReasonCode>[RewardReasonCode.applied],
    );
    expect(byId['unknown_rule']!.points, isNull);
    expect(
      byId['unknown_rule']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.periodStateMissing,
      ],
    );
  });
  test('produces identical ordered results for reversed input', () {
    final targetId = _id('target_rule');
    final rules = <RewardRule>[
      _rule(id: 'ordinary_rule', applicationOrder: 2),
      _rule(
        id: 'replacement_rule',
        applicationOrder: 0,
        stacking: _stacking(
          applicationOrder: 0,
          replacesRuleIds: <StableId>[targetId],
        ),
      ),
      _rule(id: 'target_rule', applicationOrder: 1),
    ];

    final forward = _success(
      evaluator.evaluate(rules: rules, input: _input()),
    );
    final reverse = _success(
      evaluator.evaluate(
        rules: rules.reversed,
        input: _input(),
      ),
    );

    String summary(RewardRuleEvaluationResult result) {
      return '${result.ruleId.value}:'
          '${result.points?.points}:'
          '${result.reasonCodes.map((reason) => reason.value).join(",")}';
    }

    expect(
      forward.map(summary).toList(),
      reverse.map(summary).toList(),
    );
    expect(
      forward.map((result) => result.ruleId.value),
      <String>[
        'replacement_rule',
        'target_rule',
        'ordinary_rule',
      ],
    );
  });

  test('propagates rule-set validation failure atomically', () {
    final result = evaluator.evaluate(
      rules: <RewardRule>[
        _rule(
          id: 'replacement_rule',
          stacking: _stacking(
            replacesRuleIds: <StableId>[_id('missing_rule')],
          ),
        ),
        _rule(id: 'ordinary_rule'),
      ],
      input: _input(),
    );

    final error = _failure(result);

    expect(error.code, AppErrorCode.calculationRuleInvalid);
    expect(error.operation, 'rewardRuleSet.validate');
    expect(error.context['reason'], 'referencedRuleMissing');
  });

  test('fails a dependency whose target loses an exclusive group', () {
    final prerequisiteId = _id('prerequisite_rule');
    final groupId = _id('exclusive_group');

    final results = _success(
      evaluator.evaluate(
        rules: <RewardRule>[
          _rule(
            id: 'winner_rule',
            calculation: const FixedPointsRewardCalculation(PointAmount(20)),
            stacking: _stacking(exclusiveGroupId: groupId),
          ),
          _rule(
            id: 'prerequisite_rule',
            calculation: const FixedPointsRewardCalculation(PointAmount(10)),
            stacking: _stacking(exclusiveGroupId: groupId),
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
      byId['prerequisite_rule']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.exclusiveGroupLost,
      ],
    );
    expect(
      byId['dependent_rule']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.dependencyNotSatisfied,
      ],
    );
  });
  test('propagates a deep dependency chain iteratively', () {
    const chainLength = 2000;
    final terminalId = _id(
      'dependency_${(chainLength - 1).toString().padLeft(4, '0')}',
    );

    final rules = <RewardRule>[
      for (var index = 0; index < chainLength; index++)
        _rule(
          id: 'dependency_${index.toString().padLeft(4, '0')}',
          stacking: _stacking(
            dependsOnRuleIds: index + 1 < chainLength
                ? <StableId>[
                    _id(
                      'dependency_${(index + 1).toString().padLeft(4, '0')}',
                    ),
                  ]
                : const <StableId>[],
          ),
        ),
      _rule(
        id: 'suppression_controller',
        stacking: _stacking(
          suppressesRuleIds: <StableId>[terminalId],
        ),
      ),
    ];

    final results = _success(
      evaluator.evaluate(
        rules: rules,
        input: _input(),
      ),
    );
    final byId = _byId(results);

    expect(
      byId['dependency_0000']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.dependencyNotSatisfied,
      ],
    );
    expect(
      byId['dependency_1999']!.reasonCodes,
      const <RewardReasonCode>[
        RewardReasonCode.suppressed,
      ],
    );
  });
  group('result boundary', () {
    test('aggregates final points by program in deterministic order', () {
      final firstProgramId = _id('program_one');
      final secondProgramId = _id('program_two');

      final rules = <RewardRule>[
        _rule(
          id: 'later_rule',
          applicationOrder: 2,
          outputPointProgramId: firstProgramId,
          calculation: const FixedPointsRewardCalculation(PointAmount(7)),
        ),
        _rule(
          id: 'first_rule',
          applicationOrder: 0,
          outputPointProgramId: firstProgramId,
          calculation: const FixedPointsRewardCalculation(PointAmount(5)),
        ),
        _rule(
          id: 'middle_rule',
          applicationOrder: 1,
          outputPointProgramId: secondProgramId,
          calculation: const FixedPointsRewardCalculation(PointAmount(3)),
        ),
      ];

      final forward = _resultSuccess(
        evaluator.evaluateResult(
          rules: rules,
          input: _input(),
        ),
      );
      final reversed = _resultSuccess(
        evaluator.evaluateResult(
          rules: rules.reversed,
          input: _input(),
        ),
      );

      expect(
        forward.pointsByProgram,
        <StableId, PointAmount>{
          firstProgramId: const PointAmount(12),
          secondProgramId: const PointAmount(3),
        },
      );
      expect(
        forward.ruleResults.map((result) => result.ruleId.value),
        <String>['first_rule', 'middle_rule', 'later_rule'],
      );
      expect(
        reversed.ruleResults.map((result) => result.ruleId.value),
        forward.ruleResults.map((result) => result.ruleId.value),
      );
      expect(
        reversed.trace.map((entry) => entry.ruleId.value),
        forward.trace.map((entry) => entry.ruleId.value),
      );
      expect(
        reversed.pointsByProgram,
        forward.pointsByProgram,
      );
    });

    test('records final outcomes and mirror source IDs in trace', () {
      final programId = _id('program_one');
      final sourceId = _id('source_rule');

      final result = _resultSuccess(
        evaluator.evaluateResult(
          rules: <RewardRule>[
            _rule(
              id: 'source_rule',
              outputPointProgramId: programId,
              calculation: const FixedPointsRewardCalculation(PointAmount(10)),
            ),
            _rule(
              id: 'mirror_rule',
              outputPointProgramId: programId,
              calculation: MirrorRewardCalculation(
                sourceRuleId: sourceId,
                multiplier: _rational(2, 1),
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: true,
              ),
            ),
          ],
          input: _input(),
        ),
      );

      final traceById = <String, RewardCalculationTraceEntry>{
        for (final entry in result.trace) entry.ruleId.value: entry,
      };

      expect(
        result.pointsByProgram[programId],
        const PointAmount(30),
      );
      expect(
        traceById['source_rule']!.sourceRuleId,
        isNull,
      );
      expect(
        traceById['mirror_rule']!.sourceRuleId,
        sourceId,
      );
      expect(
        traceById['mirror_rule']!.amountBefore,
        MoneyYen.zero,
      );
      expect(
        traceById['mirror_rule']!.amountAfter,
        const MoneyYen(100),
      );
      expect(
        traceById['mirror_rule']!.pointsBeforeCap,
        const PointAmount(20),
      );
      expect(
        traceById['mirror_rule']!.pointsAfterCap,
        const PointAmount(20),
      );
      expect(
        traceById['mirror_rule']!.phase,
        RewardCalculationTracePhase.finalResult,
      );
      expect(
        traceById['mirror_rule']!.details['aggregationScope'],
        'transaction',
      );
    });

    test('does not invent program points for unavailable results', () {
      final programId = _id('program_one');

      final result = _resultSuccess(
        evaluator.evaluateResult(
          rules: <RewardRule>[
            _rule(
              id: 'unknown_rule',
              outputPointProgramId: programId,
              calculation: ThresholdBonusRewardCalculation(
                thresholdAmount: const MoneyYen(1000),
                bonusPoints: const PointAmount(100),
                maxAwardsPerPeriod: 1,
              ),
            ),
          ],
          input: _input(),
        ),
      );

      expect(result.ruleResults.single.points, isNull);
      expect(result.pointsByProgram, isEmpty);
      expect(result.trace.single.pointsBeforeCap, isNull);
      expect(result.trace.single.pointsAfterCap, isNull);
    });

    test('does not add suppressed final points to program totals', () {
      final programId = _id('program_one');
      final targetId = _id('suppressed_target');

      final result = _resultSuccess(
        evaluator.evaluateResult(
          rules: <RewardRule>[
            _rule(
              id: 'suppression_controller',
              stacking: _stacking(
                suppressesRuleIds: <StableId>[targetId],
              ),
            ),
            _rule(
              id: 'suppressed_target',
              outputPointProgramId: programId,
              calculation: const FixedPointsRewardCalculation(PointAmount(100)),
            ),
            _rule(
              id: 'active_rule',
              outputPointProgramId: programId,
              calculation: const FixedPointsRewardCalculation(PointAmount(5)),
            ),
          ],
          input: _input(),
        ),
      );

      expect(
        result.pointsByProgram[programId],
        const PointAmount(5),
      );
      expect(
        result.ruleResults
            .singleWhere(
              (entry) => entry.ruleId.value == 'suppressed_target',
            )
            .reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.suppressed,
        ],
      );
    });
    test('defensively copies and freezes aggregate collections', () {
      final programId = _id('program_one');
      final ruleResult = RewardRuleEvaluationResult.calculated(
        ruleId: _id('rule_one'),
        points: const PointAmount(5),
      );
      final traceEntry = RewardCalculationTraceEntry(
        ruleId: ruleResult.ruleId,
        phase: RewardCalculationTracePhase.finalResult,
        eligibility: ruleResult.eligibility,
        confidence: ruleResult.confidence,
        reasonCodes: ruleResult.reasonCodes,
        amountBefore: const MoneyYen(100),
        amountAfter: const MoneyYen(100),
        pointsBeforeCap: const PointAmount(5),
        pointsAfterCap: const PointAmount(5),
        sourceRuleId: null,
        details: const <String, Object?>{
          'aggregationScope': 'transaction',
        },
      );
      final points = <StableId, PointAmount>{
        programId: const PointAmount(5),
      };
      final ruleResults = <RewardRuleEvaluationResult>[ruleResult];
      final trace = <RewardCalculationTraceEntry>[traceEntry];

      final result = RewardRuleSetEvaluationResult(
        pointsByProgram: points,
        ruleResults: ruleResults,
        trace: trace,
      );

      points.clear();
      ruleResults.clear();
      trace.clear();

      expect(
        result.pointsByProgram[programId],
        const PointAmount(5),
      );
      expect(result.ruleResults, hasLength(1));
      expect(result.trace, hasLength(1));
      expect(
        () => result.pointsByProgram.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => result.ruleResults.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => result.trace.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => result.trace.first.details['unsafe'] = true,
        throwsUnsupportedError,
      );
      expect(
        () => RewardCalculationTraceEntry(
          ruleId: ruleResult.ruleId,
          phase: RewardCalculationTracePhase.finalResult,
          eligibility: ruleResult.eligibility,
          confidence: ruleResult.confidence,
          reasonCodes: ruleResult.reasonCodes,
          amountBefore: MoneyYen.zero,
          amountAfter: const MoneyYen(100),
          pointsBeforeCap: const PointAmount(5),
          pointsAfterCap: const PointAmount(5),
          sourceRuleId: null,
          details: <String, Object?>{
            'nested': <String>['mutable'],
          },
        ),
        throwsArgumentError,
      );
    });

    test('fails atomically when the trace limit is exceeded', () {
      const limitedEvaluator = RewardRuleSetEvaluator(
        maximumTraceCount: 1,
      );

      final error = _resultFailure(
        limitedEvaluator.evaluateResult(
          rules: <RewardRule>[
            _rule(id: 'rule_one'),
            _rule(id: 'rule_two'),
          ],
          input: _input(),
        ),
      );

      expect(error.code, AppErrorCode.calculationOverflow);
      expect(error.operation, 'rewardRuleSet.evaluateResult');
      expect(error.context['field'], 'trace');
      expect(error.context['limit'], 1);
      expect(error.context['actual'], 2);
    });
  });
  group('mirror orchestration', () {
    test('resolves a mirror independently of input order', () {
      final sourceId = _id('source_rule');

      final results = _success(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(
              id: 'mirror_rule',
              calculation: MirrorRewardCalculation(
                sourceRuleId: sourceId,
                multiplier: _rational(3, 2),
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: false,
              ),
            ),
            _rule(
              id: 'source_rule',
              calculation: const FixedPointsRewardCalculation(PointAmount(40)),
            ),
          ],
          input: _input(),
        ),
      );

      expect(
        _byId(results)['mirror_rule']!.points,
        const PointAmount(60),
      );
    });

    test('resolves a mirror chain', () {
      final sourceId = _id('source_rule');
      final firstMirrorId = _id('first_mirror');

      final results = _success(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(
              id: 'second_mirror',
              calculation: MirrorRewardCalculation(
                sourceRuleId: firstMirrorId,
                multiplier: _rational(2, 1),
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: false,
              ),
            ),
            _rule(
              id: 'first_mirror',
              calculation: MirrorRewardCalculation(
                sourceRuleId: sourceId,
                multiplier: _rational(3, 2),
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: false,
              ),
            ),
            _rule(
              id: 'source_rule',
              calculation: const FixedPointsRewardCalculation(PointAmount(40)),
            ),
          ],
          input: _input(),
        ),
      );

      final byId = _byId(results);
      expect(byId['first_mirror']!.points, const PointAmount(60));
      expect(byId['second_mirror']!.points, const PointAmount(120));
    });

    test('inherits an explicit source exclusion when enabled', () {
      final sourceId = _id('source_rule');
      final merchantId = _id('excluded_merchant');

      final results = _success(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(
              id: 'source_rule',
              exclusions: _selectors(
                merchantIds: <StableId>[merchantId],
              ),
              calculation: const FixedPointsRewardCalculation(PointAmount(40)),
            ),
            _rule(
              id: 'mirror_rule',
              calculation: MirrorRewardCalculation(
                sourceRuleId: sourceId,
                multiplier: Rational.one,
                inheritEligibility: false,
                inheritExclusions: true,
                useFinalSourceAmount: false,
              ),
            ),
          ],
          input: _input(merchantId: merchantId),
        ),
      );

      final mirror = _byId(results)['mirror_rule']!;
      expect(mirror.points, PointAmount.zero);
      expect(
        mirror.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.excluded],
      );
    });

    test('can use raw source points when exclusion inheritance is disabled',
        () {
      final sourceId = _id('source_rule');
      final merchantId = _id('excluded_merchant');

      final results = _success(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(
              id: 'source_rule',
              exclusions: _selectors(
                merchantIds: <StableId>[merchantId],
              ),
              calculation: const FixedPointsRewardCalculation(PointAmount(40)),
            ),
            _rule(
              id: 'mirror_rule',
              calculation: MirrorRewardCalculation(
                sourceRuleId: sourceId,
                multiplier: Rational.one,
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: false,
              ),
            ),
          ],
          input: _input(merchantId: merchantId),
        ),
      );

      expect(
        _byId(results)['mirror_rule']!.points,
        const PointAmount(40),
      );
    });

    test('distinguishes raw and final source amounts', () {
      final sourceId = _id('source_rule');

      final results = _success(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(
              id: 'suppressor_rule',
              stacking: _stacking(
                suppressesRuleIds: <StableId>[sourceId],
              ),
            ),
            _rule(
              id: 'source_rule',
              calculation: const FixedPointsRewardCalculation(PointAmount(40)),
            ),
            _rule(
              id: 'raw_mirror',
              calculation: MirrorRewardCalculation(
                sourceRuleId: sourceId,
                multiplier: Rational.one,
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: false,
              ),
            ),
            _rule(
              id: 'final_mirror',
              calculation: MirrorRewardCalculation(
                sourceRuleId: sourceId,
                multiplier: Rational.one,
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: true,
              ),
            ),
          ],
          input: _input(),
        ),
      );

      final byId = _byId(results);
      expect(byId['source_rule']!.points, PointAmount.zero);
      expect(byId['raw_mirror']!.points, const PointAmount(40));
      expect(byId['final_mirror']!.points, PointAmount.zero);
    });

    test('returns mirrorSourceMissing for unavailable source points', () {
      final sourceId = _id('source_rule');

      final results = _success(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(
              id: 'source_rule',
              calculation: ThresholdBonusRewardCalculation(
                thresholdAmount: const MoneyYen(1000),
                bonusPoints: const PointAmount(100),
                maxAwardsPerPeriod: 1,
              ),
            ),
            _rule(
              id: 'mirror_rule',
              calculation: MirrorRewardCalculation(
                sourceRuleId: sourceId,
                multiplier: Rational.one,
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: true,
              ),
            ),
          ],
          input: _input(),
        ),
      );

      final mirror = _byId(results)['mirror_rule']!;
      expect(mirror.points, isNull);
      expect(
        mirror.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.mirrorSourceMissing,
        ],
      );
    });

    test('uses mirror points for exclusive-group comparison', () {
      final sourceId = _id('source_rule');
      final groupId = _id('exclusive_group');

      final results = _success(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(
              id: 'source_rule',
              calculation: const FixedPointsRewardCalculation(PointAmount(100)),
            ),
            _rule(
              id: 'mirror_candidate',
              calculation: MirrorRewardCalculation(
                sourceRuleId: sourceId,
                multiplier: _rational(2, 1),
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: true,
              ),
              stacking: _stacking(exclusiveGroupId: groupId),
            ),
            _rule(
              id: 'ordinary_candidate',
              calculation: const FixedPointsRewardCalculation(PointAmount(150)),
              stacking: _stacking(exclusiveGroupId: groupId),
            ),
          ],
          input: _input(),
        ),
      );

      final byId = _byId(results);
      expect(
        byId['mirror_candidate']!.points,
        const PointAmount(200),
      );
      expect(
        byId['ordinary_candidate']!.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.exclusiveGroupLost,
        ],
      );
    });

    test('handles a deep mirror chain without recursion', () {
      const mirrorCount = 2000;
      final rules = <RewardRule>[];

      for (var index = 0; index < mirrorCount; index++) {
        final currentId = 'mirror_${index.toString().padLeft(4, '0')}';
        final sourceId = index == mirrorCount - 1
            ? _id('source_rule')
            : _id(
                'mirror_${(index + 1).toString().padLeft(4, '0')}',
              );

        rules.add(
          _rule(
            id: currentId,
            calculation: MirrorRewardCalculation(
              sourceRuleId: sourceId,
              multiplier: Rational.one,
              inheritEligibility: false,
              inheritExclusions: false,
              useFinalSourceAmount: true,
            ),
          ),
        );
      }

      rules.add(
        _rule(
          id: 'source_rule',
          calculation: const FixedPointsRewardCalculation(PointAmount(1)),
        ),
      );

      final results = _success(
        evaluator.evaluate(
          rules: rules,
          input: _input(),
        ),
      );

      final byId = _byId(results);
      expect(byId.length, mirrorCount + 1);
      expect(
        byId['mirror_0000']!.points,
        const PointAmount(1),
      );
      expect(
        byId['mirror_1999']!.points,
        const PointAmount(1),
      );
    });
    test('propagates a non-integer mirror calculation failure', () {
      final sourceId = _id('source_rule');

      final error = _failure(
        evaluator.evaluate(
          rules: <RewardRule>[
            _rule(
              id: 'source_rule',
              calculation: const FixedPointsRewardCalculation(PointAmount(5)),
            ),
            _rule(
              id: 'mirror_rule',
              calculation: MirrorRewardCalculation(
                sourceRuleId: sourceId,
                multiplier: _rational(1, 2),
                inheritEligibility: false,
                inheritExclusions: false,
                useFinalSourceAmount: false,
              ),
            ),
          ],
          input: _input(),
        ),
      );

      expect(error.code, AppErrorCode.calculationRuleInvalid);
      expect(error.context['calculationType'], 'mirror');
      expect(error.context['reason'], 'nonIntegerMirrorResult');
    });
  });
}

RewardRule _rule({
  required String id,
  StableId? outputPointProgramId,
  SelectorSet? selectors,
  SelectorSet? exclusions,
  RewardStacking? stacking,
  RewardCalculation calculation =
      const FixedPointsRewardCalculation(PointAmount(10)),
  Iterable<StableId> tags = const <StableId>[],
  int applicationOrder = 0,
  int priority = 0,
}) {
  return RewardRule(
    id: _id(id),
    name: id,
    description: '',
    ruleKind: RewardRuleKind.baseReward,
    selectors: selectors ?? _selectors(),
    exclusions: exclusions ?? _selectors(),
    conditionExpression: null,
    calculation: calculation,
    outputPointProgramId: outputPointProgramId,
    aggregation: RewardAggregation(
      scope: RewardAggregationScope.transaction,
      aggregationKey: null,
      periodMinimumEligibleSpend: MoneyYen.zero,
      conditionEvaluationTiming: 'transaction',
      incrementalAward: false,
    ),
    stacking: stacking ?? _stacking(applicationOrder: applicationOrder),
    cap: null,
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
  StableId? exclusiveGroupId,
  int applicationOrder = 0,
}) {
  return RewardStacking(
    policy: 'stack',
    exclusiveGroupId: exclusiveGroupId,
    replacesRuleIds: replacesRuleIds,
    suppressesRuleIds: suppressesRuleIds,
    suppressesTags: suppressesTags,
    dependsOnRuleIds: dependsOnRuleIds,
    applicationOrder: applicationOrder,
  );
}

SelectorSet _selectors({
  Iterable<StableId> instrumentIds = const <StableId>[],
  Iterable<StableId> merchantIds = const <StableId>[],
}) {
  return SelectorSet(
    instrumentIds: instrumentIds,
    modeIds: const <StableId>[],
    routeIds: const <StableId>[],
    fundingRelationIds: const <StableId>[],
    merchantIds: merchantIds,
    merchantGroupIds: const <StableId>[],
    categoryIds: const <StableId>[],
    brandIds: const <StableId>[],
    locationIds: const <StableId>[],
    transactionTags: const <StableId>[],
  );
}

RewardEvaluationInput _input({
  StableId? merchantId,
}) {
  return RewardEvaluationInput(
    amount: const MoneyYen(100),
    instrumentId: null,
    modeId: null,
    routeId: null,
    merchantId: merchantId,
    transactionDate: _date('2026-06-01'),
    conditionContext: ConditionEvaluationContext(),
  );
}

Map<String, RewardRuleEvaluationResult> _byId(
  List<RewardRuleEvaluationResult> results,
) {
  return <String, RewardRuleEvaluationResult>{
    for (final result in results) result.ruleId.value: result,
  };
}

RewardRuleSetEvaluationResult _resultSuccess(
  AppResult<RewardRuleSetEvaluationResult> result,
) {
  expect(
    result,
    isA<AppSuccess<RewardRuleSetEvaluationResult>>(),
  );
  return (result as AppSuccess<RewardRuleSetEvaluationResult>).value;
}

AppError _resultFailure(
  AppResult<RewardRuleSetEvaluationResult> result,
) {
  expect(
    result,
    isA<AppFailure<RewardRuleSetEvaluationResult>>(),
  );
  return (result as AppFailure<RewardRuleSetEvaluationResult>).error;
}

List<RewardRuleEvaluationResult> _success(
  AppResult<List<RewardRuleEvaluationResult>> result,
) {
  expect(
    result,
    isA<AppSuccess<List<RewardRuleEvaluationResult>>>(),
  );
  return (result as AppSuccess<List<RewardRuleEvaluationResult>>).value;
}

AppError _failure(
  AppResult<List<RewardRuleEvaluationResult>> result,
) {
  expect(
    result,
    isA<AppFailure<List<RewardRuleEvaluationResult>>>(),
  );
  return (result as AppFailure<List<RewardRuleEvaluationResult>>).error;
}

Rational _rational(int numerator, int denominator) {
  final result = Rational.create(numerator, denominator);
  expect(result, isA<AppSuccess<Rational>>());
  return (result as AppSuccess<Rational>).value;
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

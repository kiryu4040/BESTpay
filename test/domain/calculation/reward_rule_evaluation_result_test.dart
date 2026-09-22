import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/calculation/reward_calculation_result.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';
import 'package:bestpay/domain/calculation/reward_rule_evaluation_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RewardRuleEvaluationResult', () {
    test('represents a calculated eligible rule', () {
      final result = RewardRuleEvaluationResult.calculated(
        ruleId: _id('rule_one'),
        points: const PointAmount(50),
      );

      expect(result.eligibility, TriState.satisfied);
      expect(result.points, const PointAmount(50));
      expect(result.confidence, RewardConfidence.confirmed);
      expect(
        result.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.applied],
      );
    });

    test('represents an ineligible rule with zero points', () {
      final result = RewardRuleEvaluationResult.ineligible(
        ruleId: _id('rule_one'),
        reasonCodes: const <RewardReasonCode>[
          RewardReasonCode.selectorMismatch,
        ],
      );

      expect(result.eligibility, TriState.notSatisfied);
      expect(result.points, PointAmount.zero);
      expect(result.confidence, RewardConfidence.ineligible);
    });

    test('represents an unavailable rule without invented points', () {
      final result = RewardRuleEvaluationResult.unavailable(
        ruleId: _id('rule_one'),
        confidence: RewardConfidence.unknown,
        reasonCodes: const <RewardReasonCode>[
          RewardReasonCode.missingDateBasis,
        ],
      );

      expect(result.eligibility, TriState.unknown);
      expect(result.points, isNull);
      expect(result.isCalculated, isFalse);
      expect(result.confidence, RewardConfidence.unknown);
    });

    test('converts calculated and unavailable calculation results', () {
      final ruleId = _id('rule_one');

      final calculated = RewardRuleEvaluationResult.fromCalculation(
        ruleId: ruleId,
        calculation: RewardCalculationResult.calculated(
          points: const PointAmount(100),
        ),
      );

      final unavailable = RewardRuleEvaluationResult.fromCalculation(
        ruleId: ruleId,
        calculation: RewardCalculationResult.unavailable(
          confidence: RewardConfidence.unknown,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.periodStateMissing,
          ],
        ),
      );

      expect(calculated.points, const PointAmount(100));
      expect(calculated.eligibility, TriState.satisfied);
      expect(unavailable.points, isNull);
      expect(unavailable.eligibility, TriState.unknown);
    });

    test('defensively copies and freezes reason codes', () {
      final reasons = <RewardReasonCode>[
        RewardReasonCode.excluded,
      ];
      final result = RewardRuleEvaluationResult.ineligible(
        ruleId: _id('rule_one'),
        reasonCodes: reasons,
      );

      reasons.add(RewardReasonCode.selectorMismatch);

      expect(
        result.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.excluded],
      );
      expect(
        () => result.reasonCodes.add(RewardReasonCode.applied),
        throwsUnsupportedError,
      );
    });

    test('rejects invalid calculated and unavailable states', () {
      expect(
        () => RewardRuleEvaluationResult.calculated(
          ruleId: _id('rule_one'),
          points: const PointAmount(-1),
        ),
        throwsArgumentError,
      );

      expect(
        () => RewardRuleEvaluationResult.calculated(
          ruleId: _id('rule_one'),
          points: PointAmount.zero,
          confidence: RewardConfidence.unknown,
        ),
        throwsArgumentError,
      );

      expect(
        () => RewardRuleEvaluationResult.unavailable(
          ruleId: _id('rule_one'),
          confidence: RewardConfidence.confirmed,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.conditionUnknown,
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty and duplicate reason-code lists', () {
      expect(
        () => RewardRuleEvaluationResult.ineligible(
          ruleId: _id('rule_one'),
          reasonCodes: const <RewardReasonCode>[],
        ),
        throwsArgumentError,
      );

      expect(
        () => RewardRuleEvaluationResult.ineligible(
          ruleId: _id('rule_one'),
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.excluded,
            RewardReasonCode.excluded,
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}

StableId _id(String value) {
  final result = StableId.create(value);
  expect(result, isA<AppSuccess<StableId>>());
  return (result as AppSuccess<StableId>).value;
}

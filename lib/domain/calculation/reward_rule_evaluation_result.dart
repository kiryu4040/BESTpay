import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/calculation/reward_calculation_result.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';

/// Immutable result of evaluating one reward rule.
final class RewardRuleEvaluationResult {
  RewardRuleEvaluationResult.calculated({
    required this.ruleId,
    required PointAmount points,
    RewardConfidence confidence = RewardConfidence.confirmed,
    Iterable<RewardReasonCode> reasonCodes = const <RewardReasonCode>[
      RewardReasonCode.applied
    ],
  })  : eligibility = TriState.satisfied,
        points = points,
        confidence = confidence,
        reasonCodes = _freezeReasonCodes(reasonCodes) {
    if (points.isNegative) {
      throw ArgumentError.value(
        points,
        'points',
        'Calculated rule points must not be negative.',
      );
    }

    if (confidence != RewardConfidence.confirmed &&
        confidence != RewardConfidence.estimated) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'Calculated rules must be confirmed or estimated.',
      );
    }
  }

  RewardRuleEvaluationResult.ineligible({
    required this.ruleId,
    required Iterable<RewardReasonCode> reasonCodes,
  })  : eligibility = TriState.notSatisfied,
        points = PointAmount.zero,
        confidence = RewardConfidence.ineligible,
        reasonCodes = _freezeReasonCodes(reasonCodes);

  RewardRuleEvaluationResult.unavailable({
    required this.ruleId,
    required this.confidence,
    required Iterable<RewardReasonCode> reasonCodes,
  })  : eligibility = TriState.unknown,
        points = null,
        reasonCodes = _freezeReasonCodes(reasonCodes) {
    if (confidence != RewardConfidence.unknown &&
        confidence != RewardConfidence.conditional) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'Unavailable rules must be unknown or conditional.',
      );
    }
  }

  factory RewardRuleEvaluationResult.fromCalculation({
    required StableId ruleId,
    required RewardCalculationResult calculation,
  }) {
    final points = calculation.points;

    if (points == null) {
      return RewardRuleEvaluationResult.unavailable(
        ruleId: ruleId,
        confidence: calculation.confidence,
        reasonCodes: calculation.reasonCodes,
      );
    }

    return RewardRuleEvaluationResult.calculated(
      ruleId: ruleId,
      points: points,
      confidence: calculation.confidence,
      reasonCodes: calculation.reasonCodes,
    );
  }

  final StableId ruleId;
  final TriState eligibility;
  final PointAmount? points;
  final RewardConfidence confidence;
  final List<RewardReasonCode> reasonCodes;

  bool get isCalculated => points != null;

  static List<RewardReasonCode> _freezeReasonCodes(
    Iterable<RewardReasonCode> values,
  ) {
    final result = List<RewardReasonCode>.of(values);

    if (result.isEmpty) {
      throw ArgumentError.value(
        values,
        'reasonCodes',
        'At least one reason code is required.',
      );
    }

    if (result.toSet().length != result.length) {
      throw ArgumentError.value(
        values,
        'reasonCodes',
        'Reason codes must be unique.',
      );
    }

    return List<RewardReasonCode>.unmodifiable(result);
  }
}

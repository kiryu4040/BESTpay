import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';

/// Result of evaluating only a reward rule's eligibility gates.
///
/// An eligible result deliberately contains no reward points because the
/// calculation phase has not run yet.
final class RewardRuleEligibilityResult {
  RewardRuleEligibilityResult.eligible({
    required this.ruleId,
  })  : eligibility = TriState.satisfied,
        confidence = RewardConfidence.confirmed,
        reasonCodes = const <RewardReasonCode>[];

  RewardRuleEligibilityResult.ineligible({
    required this.ruleId,
    required Iterable<RewardReasonCode> reasonCodes,
  })  : eligibility = TriState.notSatisfied,
        confidence = RewardConfidence.ineligible,
        reasonCodes = _freezeRequiredReasons(reasonCodes);

  RewardRuleEligibilityResult.unavailable({
    required this.ruleId,
    required this.confidence,
    required Iterable<RewardReasonCode> reasonCodes,
  })  : eligibility = TriState.unknown,
        reasonCodes = _freezeRequiredReasons(reasonCodes) {
    if (confidence != RewardConfidence.unknown &&
        confidence != RewardConfidence.conditional) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'Unavailable eligibility must be unknown or conditional.',
      );
    }
  }

  final StableId ruleId;
  final TriState eligibility;
  final RewardConfidence confidence;
  final List<RewardReasonCode> reasonCodes;

  bool get isEligible => eligibility == TriState.satisfied;

  static List<RewardReasonCode> _freezeRequiredReasons(
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

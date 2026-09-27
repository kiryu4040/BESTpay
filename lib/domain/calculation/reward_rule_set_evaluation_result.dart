import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';
import 'package:bestpay/domain/calculation/reward_rule_evaluation_result.dart';

/// Stable phase names emitted by the reward calculation trace.
///
/// Persist [value], never the enum index.
enum RewardCalculationTracePhase {
  finalResult('finalResult');

  const RewardCalculationTracePhase(this.value);

  final String value;
}

/// Immutable trace record for one deterministically ordered reward rule.
final class RewardCalculationTraceEntry {
  RewardCalculationTraceEntry({
    required this.ruleId,
    required this.phase,
    required this.eligibility,
    required this.confidence,
    required Iterable<RewardReasonCode> reasonCodes,
    required this.amountBefore,
    required this.amountAfter,
    required this.pointsBeforeCap,
    required this.pointsAfterCap,
    required this.sourceRuleId,
    Map<String, Object?> details = const <String, Object?>{},
  })  : reasonCodes = List<RewardReasonCode>.unmodifiable(reasonCodes),
        details = Map<String, Object?>.unmodifiable(details) {
    for (final entry in this.details.entries) {
      if (!_isSafeDetailValue(entry.value)) {
        throw ArgumentError.value(
          entry.value,
          'details',
          'Trace details must contain only null, String, int, or bool values.',
        );
      }
    }
  }

  final StableId ruleId;
  final RewardCalculationTracePhase phase;
  final TriState eligibility;
  final RewardConfidence confidence;
  final List<RewardReasonCode> reasonCodes;
  final MoneyYen amountBefore;
  final MoneyYen amountAfter;
  final PointAmount? pointsBeforeCap;
  final PointAmount? pointsAfterCap;
  final StableId? sourceRuleId;
  final Map<String, Object?> details;

  static bool _isSafeDetailValue(Object? value) {
    return value == null || value is String || value is int || value is bool;
  }
}

/// Immutable final result of evaluating and aggregating a reward-rule set.
final class RewardRuleSetEvaluationResult {
  RewardRuleSetEvaluationResult({
    required Map<StableId, PointAmount> pointsByProgram,
    required Iterable<RewardRuleEvaluationResult> ruleResults,
    required Iterable<RewardCalculationTraceEntry> trace,
  })  : pointsByProgram =
            Map<StableId, PointAmount>.unmodifiable(pointsByProgram),
        ruleResults =
            List<RewardRuleEvaluationResult>.unmodifiable(ruleResults),
        trace = List<RewardCalculationTraceEntry>.unmodifiable(trace) {
    for (final entry in this.pointsByProgram.entries) {
      if (entry.value.isNegative) {
        throw ArgumentError.value(
          entry.value,
          'pointsByProgram',
          'Aggregated program points must not be negative.',
        );
      }
    }

    if (this.ruleResults.length != this.trace.length) {
      throw ArgumentError(
        'ruleResults and trace must contain one entry per rule.',
      );
    }

    for (var index = 0; index < this.ruleResults.length; index++) {
      if (this.ruleResults[index].ruleId != this.trace[index].ruleId) {
        throw ArgumentError(
          'ruleResults and trace must use the same deterministic order.',
        );
      }
    }
  }

  final Map<StableId, PointAmount> pointsByProgram;
  final List<RewardRuleEvaluationResult> ruleResults;
  final List<RewardCalculationTraceEntry> trace;
}

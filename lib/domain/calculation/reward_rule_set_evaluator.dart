import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/calculation/reward_calculation_evaluator.dart';
import 'package:bestpay/domain/calculation/reward_calculation_result.dart';
import 'package:bestpay/domain/calculation/reward_evaluation_input.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';
import 'package:bestpay/domain/calculation/reward_rule_eligibility_result.dart';
import 'package:bestpay/domain/calculation/reward_rule_evaluation_result.dart';
import 'package:bestpay/domain/calculation/reward_rule_evaluator.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_evaluation_result.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_validator.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';

/// Evaluates a validated reward-rule set without side effects.
///
/// This boundary coordinates replacement, suppression, dependencies,
/// exclusive groups, ordinary calculations, and mirrors. Non-null caps remain
/// rejected by validation; aggregation and trace projection use a higher-level
/// result boundary.
final class RewardRuleSetEvaluator {
  const RewardRuleSetEvaluator({
    RewardRuleSetValidator validator = const RewardRuleSetValidator(),
    RewardRuleEvaluator ruleEvaluator = const RewardRuleEvaluator(),
    RewardCalculationEvaluator calculationEvaluator =
        const RewardCalculationEvaluator(),
    this.maximumTraceCount = 100000,
  })  : assert(maximumTraceCount > 0),
        _validator = validator,
        _ruleEvaluator = ruleEvaluator,
        _calculationEvaluator = calculationEvaluator;

  final RewardRuleSetValidator _validator;
  final RewardRuleEvaluator _ruleEvaluator;
  final RewardCalculationEvaluator _calculationEvaluator;
  final int maximumTraceCount;

  /// Evaluates rules and projects their final immutable aggregate result.
  ///
  /// [evaluate] remains available for callers that only need per-rule results.
  AppResult<RewardRuleSetEvaluationResult> evaluateResult({
    required Iterable<RewardRule> rules,
    required RewardEvaluationInput input,
  }) {
    final materializedRules = List<RewardRule>.unmodifiable(rules);
    final evaluation = evaluate(
      rules: materializedRules,
      input: input,
    );

    if (evaluation
        case AppFailure<List<RewardRuleEvaluationResult>>(
          error: final error,
        )) {
      return AppFailure<RewardRuleSetEvaluationResult>(error);
    }

    final ruleResults =
        (evaluation as AppSuccess<List<RewardRuleEvaluationResult>>).value;

    if (ruleResults.length > maximumTraceCount) {
      return AppFailure<RewardRuleSetEvaluationResult>(
        AppError(
          code: AppErrorCode.calculationOverflow,
          operation: 'rewardRuleSet.evaluateResult',
          context: <String, Object?>{
            'field': 'trace',
            'limit': maximumTraceCount,
            'actual': ruleResults.length,
          },
          safeMessage: 'The calculation trace limit was exceeded.',
        ),
      );
    }

    final rulesById = <StableId, RewardRule>{
      for (final rule in materializedRules) rule.id: rule,
    };
    final pointsByProgram = <StableId, PointAmount>{};
    final trace = <RewardCalculationTraceEntry>[];

    for (final ruleResult in ruleResults) {
      final rule = rulesById[ruleResult.ruleId]!;
      final programId = rule.outputPointProgramId;
      final points = ruleResult.points;

      if (programId != null && points != null) {
        final previousPoints =
            pointsByProgram[programId]?.points ?? PointAmount.zero.points;

        pointsByProgram[programId] = PointAmount(
          previousPoints + points.points,
        );
      }

      final calculation = rule.calculation;
      final sourceRuleId = calculation is MirrorRewardCalculation
          ? calculation.sourceRuleId
          : null;

      trace.add(
        RewardCalculationTraceEntry(
          ruleId: rule.id,
          phase: RewardCalculationTracePhase.finalResult,
          eligibility: ruleResult.eligibility,
          confidence: ruleResult.confidence,
          reasonCodes: ruleResult.reasonCodes,
          amountBefore: MoneyYen.zero,
          amountAfter: input.amount,
          pointsBeforeCap: ruleResult.points,
          pointsAfterCap: ruleResult.points,
          sourceRuleId: sourceRuleId,
          details: <String, Object?>{
            'aggregationScope': rule.aggregation.scope.value,
            'incrementalAward': rule.aggregation.incrementalAward,
          },
        ),
      );
    }

    return AppSuccess<RewardRuleSetEvaluationResult>(
      RewardRuleSetEvaluationResult(
        pointsByProgram: pointsByProgram,
        ruleResults: ruleResults,
        trace: trace,
      ),
    );
  }

  AppResult<List<RewardRuleEvaluationResult>> evaluate({
    required Iterable<RewardRule> rules,
    required RewardEvaluationInput input,
  }) {
    final validationResult = _validator.validateAndOrder(rules);

    if (validationResult
        case AppFailure<List<RewardRule>>(error: final error)) {
      return AppFailure<List<RewardRuleEvaluationResult>>(error);
    }

    final orderedRules =
        (validationResult as AppSuccess<List<RewardRule>>).value;

    final eligibilityByRuleId = <StableId, RewardRuleEligibilityResult>{};

    for (final rule in orderedRules) {
      final eligibilityResult = _ruleEvaluator.evaluateEligibility(
        rule: rule,
        input: input,
      );

      if (eligibilityResult
          case AppFailure<RewardRuleEligibilityResult>(
            error: final error,
          )) {
        return AppFailure<List<RewardRuleEvaluationResult>>(error);
      }

      eligibilityByRuleId[rule.id] =
          (eligibilityResult as AppSuccess<RewardRuleEligibilityResult>).value;
    }

    final replacementReasons = _resolveReplacementReasons(
      orderedRules: orderedRules,
      eligibilityByRuleId: eligibilityByRuleId,
    );

    final overriddenReasons = _resolveSuppressionReasons(
      orderedRules: orderedRules,
      eligibilityByRuleId: eligibilityByRuleId,
      replacementReasons: replacementReasons,
    );
    _applyDependencyOverrides(
      orderedRules: orderedRules,
      eligibilityByRuleId: eligibilityByRuleId,
      overriddenReasons: overriddenReasons,
    );
    final rulesById = <StableId, RewardRule>{
      for (final rule in orderedRules) rule.id: rule,
    };

    final resolutionContext = _RuleResolutionContext(
      rulesById: rulesById,
      input: input,
      eligibilityByRuleId: eligibilityByRuleId,
      overriddenReasons: overriddenReasons,
      calculationEvaluator: _calculationEvaluator,
    );

    final exclusiveGroups = <StableId, List<RewardRule>>{};
    final unresolvedGroups = <StableId>{};

    for (final rule in orderedRules) {
      final groupId = rule.stacking.exclusiveGroupId;
      if (groupId == null || overriddenReasons.containsKey(rule.id)) {
        continue;
      }

      final eligibility = eligibilityByRuleId[rule.id]!;
      if (eligibility.eligibility == TriState.unknown) {
        unresolvedGroups.add(groupId);
        continue;
      }

      if (!eligibility.isEligible) {
        continue;
      }

      final provisionalResult = resolutionContext.resolveRaw(rule.id);

      if (provisionalResult
          case AppFailure<RewardRuleEvaluationResult>(
            error: final error,
          )) {
        return AppFailure<List<RewardRuleEvaluationResult>>(error);
      }

      final result =
          (provisionalResult as AppSuccess<RewardRuleEvaluationResult>).value;

      if (result.eligibility == TriState.unknown) {
        unresolvedGroups.add(groupId);
        continue;
      }

      if (result.eligibility != TriState.satisfied) {
        continue;
      }

      exclusiveGroups.putIfAbsent(groupId, () => <RewardRule>[]).add(rule);

      if (!result.isCalculated) {
        unresolvedGroups.add(groupId);
      }
    }

    for (final entry in exclusiveGroups.entries) {
      if (unresolvedGroups.contains(entry.key)) {
        continue;
      }

      final candidates = entry.value;
      if (candidates.length < 2) {
        continue;
      }

      candidates.sort((left, right) {
        final leftResult = resolutionContext.rawResult(left.id)!;
        final rightResult = resolutionContext.rawResult(right.id)!;
        final leftPoints = leftResult.points!;
        final rightPoints = rightResult.points!;

        final pointsComparison = rightPoints.compareTo(leftPoints);
        if (pointsComparison != 0) {
          return pointsComparison;
        }

        final priorityComparison = right.priority.compareTo(left.priority);
        if (priorityComparison != 0) {
          return priorityComparison;
        }

        final applicationOrderComparison =
            left.stacking.applicationOrder.compareTo(
          right.stacking.applicationOrder,
        );
        if (applicationOrderComparison != 0) {
          return applicationOrderComparison;
        }

        return left.id.value.compareTo(right.id.value);
      });

      for (final loser in candidates.skip(1)) {
        overriddenReasons[loser.id] = RewardReasonCode.exclusiveGroupLost;
      }
    }

    _applyDependencyOverrides(
      orderedRules: orderedRules,
      eligibilityByRuleId: eligibilityByRuleId,
      overriddenReasons: overriddenReasons,
    );
    final results = <RewardRuleEvaluationResult>[];

    for (final rule in orderedRules) {
      final ruleResult = resolutionContext.resolveFinal(rule.id);

      if (ruleResult
          case AppFailure<RewardRuleEvaluationResult>(
            error: final error,
          )) {
        return AppFailure<List<RewardRuleEvaluationResult>>(error);
      }

      results.add(
        (ruleResult as AppSuccess<RewardRuleEvaluationResult>).value,
      );
    }

    return AppSuccess<List<RewardRuleEvaluationResult>>(
      List<RewardRuleEvaluationResult>.unmodifiable(results),
    );
  }

  Map<StableId, RewardReasonCode> _resolveReplacementReasons({
    required List<RewardRule> orderedRules,
    required Map<StableId, RewardRuleEligibilityResult> eligibilityByRuleId,
  }) {
    final targetsBySource = <StableId, List<StableId>>{
      for (final rule in orderedRules) rule.id: rule.stacking.replacesRuleIds,
    };

    return _resolveGraphOverrides(
      orderedRules: orderedRules,
      eligibilityByRuleId: eligibilityByRuleId,
      targetsBySource: targetsBySource,
      initialReasons: const <StableId, RewardReasonCode>{},
      overrideReason: RewardReasonCode.replaced,
    );
  }

  Map<StableId, RewardReasonCode> _resolveSuppressionReasons({
    required List<RewardRule> orderedRules,
    required Map<StableId, RewardRuleEligibilityResult> eligibilityByRuleId,
    required Map<StableId, RewardReasonCode> replacementReasons,
  }) {
    final rulesByTag = <StableId, List<StableId>>{};

    for (final rule in orderedRules) {
      for (final tag in rule.tags) {
        rulesByTag.putIfAbsent(tag, () => <StableId>[]).add(rule.id);
      }
    }

    final targetsBySource = <StableId, List<StableId>>{};

    for (final source in orderedRules) {
      final targets = <StableId>{
        ...source.stacking.suppressesRuleIds,
      };

      for (final tag in source.stacking.suppressesTags) {
        targets.addAll(rulesByTag[tag] ?? const <StableId>[]);
      }

      targetsBySource[source.id] = List<StableId>.unmodifiable(targets);
    }

    return _resolveGraphOverrides(
      orderedRules: orderedRules,
      eligibilityByRuleId: eligibilityByRuleId,
      targetsBySource: targetsBySource,
      initialReasons: replacementReasons,
      overrideReason: RewardReasonCode.suppressed,
    );
  }

  Map<StableId, RewardReasonCode> _resolveGraphOverrides({
    required List<RewardRule> orderedRules,
    required Map<StableId, RewardRuleEligibilityResult> eligibilityByRuleId,
    required Map<StableId, List<StableId>> targetsBySource,
    required Map<StableId, RewardReasonCode> initialReasons,
    required RewardReasonCode overrideReason,
  }) {
    final incomingCount = <StableId, int>{
      for (final rule in orderedRules) rule.id: 0,
    };

    for (final targets in targetsBySource.values) {
      for (final targetId in targets) {
        incomingCount[targetId] = incomingCount[targetId]! + 1;
      }
    }

    final queue = <StableId>[
      for (final rule in orderedRules)
        if (incomingCount[rule.id] == 0) rule.id,
    ];

    final result = <StableId, RewardReasonCode>{
      ...initialReasons,
    };

    var queueIndex = 0;

    while (queueIndex < queue.length) {
      final sourceId = queue[queueIndex];
      queueIndex += 1;

      final sourceActive = eligibilityByRuleId[sourceId]!.isEligible &&
          !result.containsKey(sourceId);

      for (final targetId in targetsBySource[sourceId] ?? const <StableId>[]) {
        if (sourceActive) {
          final targetEligibility = eligibilityByRuleId[targetId]!;

          if (!_isExplicitlyExcluded(targetEligibility)) {
            result.putIfAbsent(targetId, () => overrideReason);
          }
        }

        final remaining = incomingCount[targetId]! - 1;
        incomingCount[targetId] = remaining;

        if (remaining == 0) {
          queue.add(targetId);
        }
      }
    }

    return result;
  }

  void _applyDependencyOverrides({
    required List<RewardRule> orderedRules,
    required Map<StableId, RewardRuleEligibilityResult> eligibilityByRuleId,
    required Map<StableId, RewardReasonCode> overriddenReasons,
  }) {
    final dependentsByRuleId = <StableId, List<StableId>>{
      for (final rule in orderedRules) rule.id: <StableId>[],
    };

    for (final rule in orderedRules) {
      for (final dependencyId in rule.stacking.dependsOnRuleIds) {
        dependentsByRuleId[dependencyId]!.add(rule.id);
      }
    }

    final inactiveRuleIds = <StableId>{
      for (final rule in orderedRules)
        if (!eligibilityByRuleId[rule.id]!.isEligible ||
            overriddenReasons.containsKey(rule.id))
          rule.id,
    };
    final queue = <StableId>[...inactiveRuleIds];
    var queueIndex = 0;

    while (queueIndex < queue.length) {
      final inactiveRuleId = queue[queueIndex];
      queueIndex += 1;

      for (final dependentId
          in dependentsByRuleId[inactiveRuleId] ?? const <StableId>[]) {
        if (overriddenReasons.containsKey(dependentId)) {
          continue;
        }

        final dependentEligibility = eligibilityByRuleId[dependentId]!;
        if (!dependentEligibility.isEligible) {
          continue;
        }

        overriddenReasons[dependentId] =
            RewardReasonCode.dependencyNotSatisfied;

        if (inactiveRuleIds.add(dependentId)) {
          queue.add(dependentId);
        }
      }
    }
  }

  bool _isExplicitlyExcluded(
    RewardRuleEligibilityResult result,
  ) {
    return result.reasonCodes.contains(RewardReasonCode.excluded);
  }
}

final class _RuleResolutionContext {
  _RuleResolutionContext({
    required this.rulesById,
    required this.input,
    required this.eligibilityByRuleId,
    required this.overriddenReasons,
    required this.calculationEvaluator,
  });

  final Map<StableId, RewardRule> rulesById;
  final RewardEvaluationInput input;
  final Map<StableId, RewardRuleEligibilityResult> eligibilityByRuleId;
  final Map<StableId, RewardReasonCode> overriddenReasons;
  final RewardCalculationEvaluator calculationEvaluator;

  final Map<StableId, RewardRuleEvaluationResult> _rawResults =
      <StableId, RewardRuleEvaluationResult>{};
  final Map<StableId, RewardRuleEvaluationResult> _finalResults =
      <StableId, RewardRuleEvaluationResult>{};

  RewardRuleEvaluationResult? rawResult(StableId ruleId) {
    return _rawResults[ruleId];
  }

  AppResult<RewardRuleEvaluationResult> resolveRaw(StableId ruleId) {
    final pendingMirrors = <RewardRule>[];
    var currentRuleId = ruleId;
    AppResult<RewardRuleEvaluationResult>? resolved;

    while (resolved == null) {
      final cached = _rawResults[currentRuleId];
      if (cached != null) {
        resolved = AppSuccess<RewardRuleEvaluationResult>(cached);
        break;
      }

      final rule = rulesById[currentRuleId]!;
      final calculation = rule.calculation;

      if (calculation is MirrorRewardCalculation) {
        final inherited = _inheritedResult(
          mirrorRuleId: rule.id,
          calculation: calculation,
        );

        if (inherited != null) {
          _rawResults[rule.id] = inherited;
          resolved = AppSuccess<RewardRuleEvaluationResult>(inherited);
          break;
        }

        pendingMirrors.add(rule);
        currentRuleId = calculation.sourceRuleId;
        continue;
      }

      resolved = _evaluateOrdinary(
        rule: rule,
        cache: _rawResults,
      );
    }

    if (resolved
        case AppFailure<RewardRuleEvaluationResult>(error: final error)) {
      return AppFailure<RewardRuleEvaluationResult>(error);
    }

    var value = (resolved as AppSuccess<RewardRuleEvaluationResult>).value;

    while (pendingMirrors.isNotEmpty) {
      final rule = pendingMirrors.removeLast();
      final calculation = rule.calculation as MirrorRewardCalculation;

      final mirrorResult = _completeMirror(
        rule: rule,
        calculation: calculation,
        source: value,
        cache: _rawResults,
      );

      if (mirrorResult
          case AppFailure<RewardRuleEvaluationResult>(error: final error)) {
        return AppFailure<RewardRuleEvaluationResult>(error);
      }

      value = (mirrorResult as AppSuccess<RewardRuleEvaluationResult>).value;
    }

    return AppSuccess<RewardRuleEvaluationResult>(value);
  }

  AppResult<RewardRuleEvaluationResult> resolveFinal(StableId ruleId) {
    final pendingMirrors = <RewardRule>[];
    var currentRuleId = ruleId;
    AppResult<RewardRuleEvaluationResult>? resolved;

    while (resolved == null) {
      final cached = _finalResults[currentRuleId];
      if (cached != null) {
        resolved = AppSuccess<RewardRuleEvaluationResult>(cached);
        break;
      }

      final overrideReason = overriddenReasons[currentRuleId];
      if (overrideReason != null) {
        final result = RewardRuleEvaluationResult.ineligible(
          ruleId: currentRuleId,
          reasonCodes: <RewardReasonCode>[overrideReason],
        );
        _finalResults[currentRuleId] = result;
        resolved = AppSuccess<RewardRuleEvaluationResult>(result);
        break;
      }

      final eligibility = eligibilityByRuleId[currentRuleId]!;
      if (!eligibility.isEligible) {
        final result = _fromEligibility(eligibility);
        _finalResults[currentRuleId] = result;
        resolved = AppSuccess<RewardRuleEvaluationResult>(result);
        break;
      }

      final rule = rulesById[currentRuleId]!;
      final calculation = rule.calculation;

      if (calculation is! MirrorRewardCalculation) {
        final rawResult = resolveRaw(rule.id);

        if (rawResult
            case AppSuccess<RewardRuleEvaluationResult>(
              value: final value,
            )) {
          _finalResults[rule.id] = value;
        }

        resolved = rawResult;
        break;
      }

      final inherited = _inheritedResult(
        mirrorRuleId: rule.id,
        calculation: calculation,
      );

      if (inherited != null) {
        _finalResults[rule.id] = inherited;
        resolved = AppSuccess<RewardRuleEvaluationResult>(inherited);
        break;
      }

      pendingMirrors.add(rule);

      if (calculation.useFinalSourceAmount) {
        currentRuleId = calculation.sourceRuleId;
        continue;
      }

      resolved = resolveRaw(calculation.sourceRuleId);
    }

    if (resolved
        case AppFailure<RewardRuleEvaluationResult>(error: final error)) {
      return AppFailure<RewardRuleEvaluationResult>(error);
    }

    var value = (resolved as AppSuccess<RewardRuleEvaluationResult>).value;

    while (pendingMirrors.isNotEmpty) {
      final rule = pendingMirrors.removeLast();
      final calculation = rule.calculation as MirrorRewardCalculation;

      final mirrorResult = _completeMirror(
        rule: rule,
        calculation: calculation,
        source: value,
        cache: _finalResults,
      );

      if (mirrorResult
          case AppFailure<RewardRuleEvaluationResult>(error: final error)) {
        return AppFailure<RewardRuleEvaluationResult>(error);
      }

      value = (mirrorResult as AppSuccess<RewardRuleEvaluationResult>).value;
    }

    return AppSuccess<RewardRuleEvaluationResult>(value);
  }

  RewardRuleEvaluationResult? _inheritedResult({
    required StableId mirrorRuleId,
    required MirrorRewardCalculation calculation,
  }) {
    final sourceEligibility = eligibilityByRuleId[calculation.sourceRuleId]!;

    final sourceExcluded = sourceEligibility.reasonCodes.contains(
      RewardReasonCode.excluded,
    );

    if (sourceExcluded) {
      if (calculation.inheritExclusions) {
        return RewardRuleEvaluationResult.ineligible(
          ruleId: mirrorRuleId,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.excluded,
          ],
        );
      }

      return null;
    }

    if (calculation.inheritEligibility && !sourceEligibility.isEligible) {
      return _fromEligibility(
        sourceEligibility,
        ruleId: mirrorRuleId,
      );
    }

    return null;
  }

  AppResult<RewardRuleEvaluationResult> _evaluateOrdinary({
    required RewardRule rule,
    required Map<StableId, RewardRuleEvaluationResult> cache,
  }) {
    final calculationResult = calculationEvaluator.evaluateResult(
      calculation: rule.calculation,
      amount: input.amount,
      periodSnapshot: input.thresholdPeriodSnapshot,
    );

    return switch (calculationResult) {
      AppSuccess(value: final calculationValue) => _cacheSuccessfulCalculation(
          ruleId: rule.id,
          calculation: calculationValue,
          cache: cache,
        ),
      AppFailure(error: final error) =>
        AppFailure<RewardRuleEvaluationResult>(error),
    };
  }

  AppResult<RewardRuleEvaluationResult> _completeMirror({
    required RewardRule rule,
    required MirrorRewardCalculation calculation,
    required RewardRuleEvaluationResult source,
    required Map<StableId, RewardRuleEvaluationResult> cache,
  }) {
    final sourcePoints = source.points;

    if (sourcePoints == null) {
      final result = RewardRuleEvaluationResult.unavailable(
        ruleId: rule.id,
        confidence: source.confidence,
        reasonCodes: const <RewardReasonCode>[
          RewardReasonCode.mirrorSourceMissing,
        ],
      );
      cache[rule.id] = result;
      return AppSuccess<RewardRuleEvaluationResult>(result);
    }

    final calculationResult = calculationEvaluator.evaluateMirror(
      calculation: calculation,
      sourcePoints: sourcePoints,
    );

    return switch (calculationResult) {
      AppSuccess(value: final calculationValue) => _cacheSuccessfulCalculation(
          ruleId: rule.id,
          calculation: calculationValue,
          cache: cache,
        ),
      AppFailure(error: final error) =>
        AppFailure<RewardRuleEvaluationResult>(error),
    };
  }

  AppResult<RewardRuleEvaluationResult> _cacheSuccessfulCalculation({
    required StableId ruleId,
    required RewardCalculationResult calculation,
    required Map<StableId, RewardRuleEvaluationResult> cache,
  }) {
    final result = RewardRuleEvaluationResult.fromCalculation(
      ruleId: ruleId,
      calculation: calculation,
    );
    cache[ruleId] = result;
    return AppSuccess<RewardRuleEvaluationResult>(result);
  }

  RewardRuleEvaluationResult _fromEligibility(
    RewardRuleEligibilityResult eligibility, {
    StableId? ruleId,
  }) {
    final resultRuleId = ruleId ?? eligibility.ruleId;

    return switch (eligibility.eligibility) {
      TriState.satisfied => throw StateError(
          'Eligible rules must proceed to calculation.',
        ),
      TriState.notSatisfied ||
      TriState.notApplicable =>
        RewardRuleEvaluationResult.ineligible(
          ruleId: resultRuleId,
          reasonCodes: eligibility.reasonCodes,
        ),
      TriState.unknown => RewardRuleEvaluationResult.unavailable(
          ruleId: resultRuleId,
          confidence: eligibility.confidence,
          reasonCodes: eligibility.reasonCodes,
        ),
    };
  }
}

import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';

/// Validates a complete reward-rule set before multi-rule evaluation.
///
/// Validation is atomic: callers must not begin evaluation when this boundary
/// returns a failure. The successful list is immutable and deterministically
/// ordered independently of the input order.
final class RewardRuleSetValidator {
  const RewardRuleSetValidator({
    this.maximumRuleCount = 10000,
    this.maximumIdsPerAxis = 10000,
  })  : assert(maximumRuleCount > 0),
        assert(maximumIdsPerAxis > 0);

  static const String _operation = 'rewardRuleSet.validate';

  final int maximumRuleCount;
  final int maximumIdsPerAxis;

  AppResult<List<RewardRule>> validateAndOrder(
    Iterable<RewardRule> rules,
  ) {
    final ruleList = List<RewardRule>.of(rules);

    if (ruleList.length > maximumRuleCount) {
      return AppFailure<List<RewardRule>>(
        _error(
          code: AppErrorCode.calculationOverflow,
          field: 'rules',
          reason: 'ruleLimitExceeded',
          limit: maximumRuleCount,
        ),
      );
    }

    final seenIds = <StableId>{};
    for (final rule in ruleList) {
      if (!seenIds.add(rule.id)) {
        return AppFailure<List<RewardRule>>(
          _error(
            code: AppErrorCode.calculationRuleInvalid,
            field: 'ruleId',
            reason: 'duplicateRuleId',
            ruleId: rule.id,
          ),
        );
      }
    }

    final ordered = List<RewardRule>.of(ruleList)..sort(_compareRules);
    final rulesById = <StableId, RewardRule>{
      for (final rule in ordered) rule.id: rule,
    };

    for (final rule in ordered) {
      final limitError = _validatePerRuleLimits(rule);
      if (limitError != null) {
        return AppFailure<List<RewardRule>>(limitError);
      }

      final aggregationError = _validateAggregation(rule);
      if (aggregationError != null) {
        return AppFailure<List<RewardRule>>(aggregationError);
      }

      if (rule.cap != null) {
        return AppFailure<List<RewardRule>>(
          _error(
            code: AppErrorCode.calculationRuleInvalid,
            field: 'cap',
            reason: 'unsupportedCap',
            ruleId: rule.id,
          ),
        );
      }

      final replacementError = _validateReferences(
        rule: rule,
        field: 'replacesRuleIds',
        references: rule.stacking.replacesRuleIds,
        rulesById: rulesById,
        selfReason: 'selfReplacement',
      );
      if (replacementError != null) {
        return AppFailure<List<RewardRule>>(replacementError);
      }

      final suppressionError = _validateReferences(
        rule: rule,
        field: 'suppressesRuleIds',
        references: rule.stacking.suppressesRuleIds,
        rulesById: rulesById,
        selfReason: 'selfSuppression',
      );
      if (suppressionError != null) {
        return AppFailure<List<RewardRule>>(suppressionError);
      }

      final dependencyError = _validateReferences(
        rule: rule,
        field: 'dependsOnRuleIds',
        references: rule.stacking.dependsOnRuleIds,
        rulesById: rulesById,
        selfReason: 'dependencyCycle',
      );
      if (dependencyError != null) {
        return AppFailure<List<RewardRule>>(dependencyError);
      }

      final calculation = rule.calculation;
      if (calculation is MirrorRewardCalculation) {
        final sourceRuleId = calculation.sourceRuleId;

        if (sourceRuleId == rule.id) {
          return AppFailure<List<RewardRule>>(
            _error(
              code: AppErrorCode.calculationRuleInvalid,
              field: 'calculation.sourceRuleId',
              reason: 'mirrorCycle',
              ruleId: rule.id,
              referenceRuleId: sourceRuleId,
            ),
          );
        }

        if (!rulesById.containsKey(sourceRuleId)) {
          return AppFailure<List<RewardRule>>(
            _error(
              code: AppErrorCode.calculationRuleInvalid,
              field: 'calculation.sourceRuleId',
              reason: 'referencedRuleMissing',
              ruleId: rule.id,
              referenceRuleId: sourceRuleId,
            ),
          );
        }

        final sourceRule = rulesById[sourceRuleId]!;

        if (rule.aggregation.scope != RewardAggregationScope.transaction ||
            sourceRule.aggregation.scope !=
                RewardAggregationScope.transaction) {
          return AppFailure<List<RewardRule>>(
            _error(
              code: AppErrorCode.calculationRuleInvalid,
              field: 'calculation',
              reason: 'unsupportedPeriodMirror',
              ruleId: rule.id,
              referenceRuleId: sourceRuleId,
            ),
          );
        }
      }
    }

    if (_hasCycle(
      ordered,
      (rule) => rule.stacking.replacesRuleIds,
    )) {
      return AppFailure<List<RewardRule>>(
        _error(
          code: AppErrorCode.calculationRuleInvalid,
          field: 'replacesRuleIds',
          reason: 'replacementCycle',
        ),
      );
    }

    if (_hasCycle(
      ordered,
      (rule) => rule.stacking.dependsOnRuleIds,
    )) {
      return AppFailure<List<RewardRule>>(
        _error(
          code: AppErrorCode.calculationRuleInvalid,
          field: 'dependsOnRuleIds',
          reason: 'dependencyCycle',
        ),
      );
    }

    final ruleIdsByTag = <StableId, List<StableId>>{};

    for (final rule in ordered) {
      for (final tag in rule.tags) {
        ruleIdsByTag.putIfAbsent(tag, () => <StableId>[]).add(rule.id);
      }
    }

    if (_hasCycle(
      ordered,
      (source) {
        final targets = <StableId>{
          ...source.stacking.suppressesRuleIds,
        };

        for (final tag in source.stacking.suppressesTags) {
          targets.addAll(ruleIdsByTag[tag] ?? const <StableId>[]);
        }

        return targets;
      },
    )) {
      return AppFailure<List<RewardRule>>(
        _error(
          code: AppErrorCode.calculationRuleInvalid,
          field: 'suppressesRuleIds',
          reason: 'suppressionCycle',
        ),
      );
    }
    if (_hasCycle(
      ordered,
      (rule) {
        final calculation = rule.calculation;
        return calculation is MirrorRewardCalculation
            ? <StableId>[calculation.sourceRuleId]
            : const <StableId>[];
      },
    )) {
      return AppFailure<List<RewardRule>>(
        _error(
          code: AppErrorCode.calculationRuleInvalid,
          field: 'calculation.sourceRuleId',
          reason: 'mirrorCycle',
        ),
      );
    }

    return AppSuccess<List<RewardRule>>(
      List<RewardRule>.unmodifiable(ordered),
    );
  }

  AppError? _validateAggregation(RewardRule rule) {
    final aggregation = rule.aggregation;
    final isTransaction =
        aggregation.scope == RewardAggregationScope.transaction;

    if (aggregation.conditionEvaluationTiming != 'transaction') {
      return _error(
        code: AppErrorCode.calculationRuleInvalid,
        field: 'aggregation.conditionEvaluationTiming',
        reason: 'unsupportedConditionEvaluationTiming',
        ruleId: rule.id,
      );
    }

    if (isTransaction) {
      if (aggregation.aggregationKey != null) {
        return _error(
          code: AppErrorCode.calculationRuleInvalid,
          field: 'aggregation.aggregationKey',
          reason: 'unsupportedAggregationKey',
          ruleId: rule.id,
        );
      }

      if (aggregation.periodMinimumEligibleSpend.yen != 0) {
        return _error(
          code: AppErrorCode.calculationRuleInvalid,
          field: 'aggregation.periodMinimumEligibleSpend',
          reason: 'unsupportedPeriodMinimumEligibleSpend',
          ruleId: rule.id,
        );
      }

      if (aggregation.incrementalAward) {
        return _error(
          code: AppErrorCode.calculationRuleInvalid,
          field: 'aggregation.incrementalAward',
          reason: 'unsupportedIncrementalAward',
          ruleId: rule.id,
        );
      }

      return null;
    }

    if (aggregation.aggregationKey == null) {
      return _error(
        code: AppErrorCode.calculationRuleInvalid,
        field: 'aggregation.aggregationKey',
        reason: 'aggregationKeyRequired',
        ruleId: rule.id,
      );
    }

    if (!aggregation.incrementalAward) {
      return _error(
        code: AppErrorCode.calculationRuleInvalid,
        field: 'aggregation.incrementalAward',
        reason: 'periodEndAwardNotImplemented',
        ruleId: rule.id,
      );
    }

    return null;
  }

  AppError? _validatePerRuleLimits(RewardRule rule) {
    final selectorAxes = <String, List<StableId>>{
      'selectors.instrumentIds': rule.selectors.instrumentIds,
      'selectors.modeIds': rule.selectors.modeIds,
      'selectors.routeIds': rule.selectors.routeIds,
      'selectors.fundingRelationIds': rule.selectors.fundingRelationIds,
      'selectors.merchantIds': rule.selectors.merchantIds,
      'selectors.merchantGroupIds': rule.selectors.merchantGroupIds,
      'selectors.categoryIds': rule.selectors.categoryIds,
      'selectors.brandIds': rule.selectors.brandIds,
      'selectors.locationIds': rule.selectors.locationIds,
      'selectors.transactionTags': rule.selectors.transactionTags,
      'exclusions.instrumentIds': rule.exclusions.instrumentIds,
      'exclusions.modeIds': rule.exclusions.modeIds,
      'exclusions.routeIds': rule.exclusions.routeIds,
      'exclusions.fundingRelationIds': rule.exclusions.fundingRelationIds,
      'exclusions.merchantIds': rule.exclusions.merchantIds,
      'exclusions.merchantGroupIds': rule.exclusions.merchantGroupIds,
      'exclusions.categoryIds': rule.exclusions.categoryIds,
      'exclusions.brandIds': rule.exclusions.brandIds,
      'exclusions.locationIds': rule.exclusions.locationIds,
      'exclusions.transactionTags': rule.exclusions.transactionTags,
    };

    for (final entry in selectorAxes.entries) {
      if (entry.value.length > maximumIdsPerAxis) {
        return _error(
          code: AppErrorCode.calculationOverflow,
          field: entry.key,
          reason: 'selectorIdLimitExceeded',
          ruleId: rule.id,
          limit: maximumIdsPerAxis,
        );
      }
    }

    final relationAxes = <String, List<StableId>>{
      'replacesRuleIds': rule.stacking.replacesRuleIds,
      'suppressesRuleIds': rule.stacking.suppressesRuleIds,
      'suppressesTags': rule.stacking.suppressesTags,
      'dependsOnRuleIds': rule.stacking.dependsOnRuleIds,
    };

    for (final entry in relationAxes.entries) {
      if (entry.value.length > maximumIdsPerAxis) {
        return _error(
          code: AppErrorCode.calculationOverflow,
          field: entry.key,
          reason: 'relationIdLimitExceeded',
          ruleId: rule.id,
          limit: maximumIdsPerAxis,
        );
      }
    }

    return null;
  }

  AppError? _validateReferences({
    required RewardRule rule,
    required String field,
    required List<StableId> references,
    required Map<StableId, RewardRule> rulesById,
    required String selfReason,
  }) {
    for (final reference in references) {
      if (reference == rule.id) {
        return _error(
          code: AppErrorCode.calculationRuleInvalid,
          field: field,
          reason: selfReason,
          ruleId: rule.id,
          referenceRuleId: reference,
        );
      }

      if (!rulesById.containsKey(reference)) {
        return _error(
          code: AppErrorCode.calculationRuleInvalid,
          field: field,
          reason: 'referencedRuleMissing',
          ruleId: rule.id,
          referenceRuleId: reference,
        );
      }
    }

    return null;
  }

  bool _hasCycle(
    List<RewardRule> rules,
    Iterable<StableId> Function(RewardRule rule) referencesFor,
  ) {
    final incomingCount = <StableId, int>{
      for (final rule in rules) rule.id: 0,
    };
    final edges = <StableId, List<StableId>>{
      for (final rule in rules) rule.id: List<StableId>.of(referencesFor(rule)),
    };

    for (final references in edges.values) {
      for (final reference in references) {
        incomingCount[reference] = incomingCount[reference]! + 1;
      }
    }

    final queue = <StableId>[
      for (final entry in incomingCount.entries)
        if (entry.value == 0) entry.key,
    ]..sort((left, right) => left.value.compareTo(right.value));

    var processed = 0;
    var queueIndex = 0;

    while (queueIndex < queue.length) {
      final ruleId = queue[queueIndex];
      queueIndex += 1;
      processed += 1;

      for (final reference in edges[ruleId]!) {
        final remaining = incomingCount[reference]! - 1;
        incomingCount[reference] = remaining;

        if (remaining == 0) {
          queue.add(reference);
        }
      }
    }

    return processed != rules.length;
  }

  int _compareRules(RewardRule left, RewardRule right) {
    final applicationOrderComparison = left.stacking.applicationOrder
        .compareTo(right.stacking.applicationOrder);
    if (applicationOrderComparison != 0) {
      return applicationOrderComparison;
    }

    final priorityComparison = right.priority.compareTo(left.priority);
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    return left.id.value.compareTo(right.id.value);
  }

  AppError _error({
    required AppErrorCode code,
    required String field,
    required String reason,
    StableId? ruleId,
    StableId? referenceRuleId,
    int? limit,
  }) {
    return AppError(
      code: code,
      operation: _operation,
      context: <String, Object?>{
        'field': field,
        'reason': reason,
        if (ruleId != null) 'ruleId': ruleId.value,
        if (referenceRuleId != null) 'referenceRuleId': referenceRuleId.value,
        if (limit != null) 'limit': limit,
      },
    );
  }
}

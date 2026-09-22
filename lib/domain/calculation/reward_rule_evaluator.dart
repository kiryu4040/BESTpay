import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/calculation/condition_evaluator.dart';
import 'package:bestpay/domain/calculation/reward_calculation_evaluator.dart';
import 'package:bestpay/domain/calculation/reward_evaluation_input.dart';
import 'package:bestpay/domain/calculation/reward_rule_eligibility_result.dart';
import 'package:bestpay/domain/calculation/reward_rule_evaluation_result.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';

/// Evaluates the eligibility and calculation of one reward rule.
///
/// Multi-rule replacement, suppression, dependency, exclusive-group, and
/// mirror orchestration is handled by [RewardRuleSetEvaluator]. Non-null caps
/// remain rejected at the rule-set validation boundary.
final class RewardRuleEvaluator {
  const RewardRuleEvaluator({
    ConditionEvaluator conditionEvaluator = const ConditionEvaluator(),
    RewardCalculationEvaluator calculationEvaluator =
        const RewardCalculationEvaluator(),
  })  : _conditionEvaluator = conditionEvaluator,
        _calculationEvaluator = calculationEvaluator;

  static const String _operation = 'rewardRule.evaluate';

  final ConditionEvaluator _conditionEvaluator;
  final RewardCalculationEvaluator _calculationEvaluator;

  /// Evaluates selectors, exclusions, dates, and conditions without running
  /// the reward calculation.
  AppResult<RewardRuleEligibilityResult> evaluateEligibility({
    required RewardRule rule,
    required RewardEvaluationInput input,
  }) {
    if (input.amount.isNegative) {
      return _failure<RewardRuleEligibilityResult>(
        rule: rule,
        code: AppErrorCode.calculationInputInvalid,
        field: 'amount',
        safeMessage: 'The transaction amount must not be negative.',
      );
    }

    if (_matchesAnyAxis(rule.exclusions, input)) {
      return AppSuccess<RewardRuleEligibilityResult>(
        RewardRuleEligibilityResult.ineligible(
          ruleId: rule.id,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.excluded,
          ],
        ),
      );
    }

    if (!_matchesAllAxes(rule.selectors, input)) {
      return AppSuccess<RewardRuleEligibilityResult>(
        RewardRuleEligibilityResult.ineligible(
          ruleId: rule.id,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.selectorMismatch,
          ],
        ),
      );
    }

    final evaluationDate = input.dateFor(rule.dateBasis);
    if (evaluationDate == null) {
      return AppSuccess<RewardRuleEligibilityResult>(
        RewardRuleEligibilityResult.unavailable(
          ruleId: rule.id,
          confidence: RewardConfidence.unknown,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.missingDateBasis,
          ],
        ),
      );
    }

    if (!rule.validityPeriod.contains(evaluationDate)) {
      return AppSuccess<RewardRuleEligibilityResult>(
        RewardRuleEligibilityResult.ineligible(
          ruleId: rule.id,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.outsideValidityPeriod,
          ],
        ),
      );
    }

    final conditionExpression = rule.conditionExpression;
    if (conditionExpression != null) {
      final conditionResult = _conditionEvaluator.evaluate(
        conditionExpression,
        input.conditionContext,
      );

      if (conditionResult
          case AppFailure<TriState>(error: final conditionError)) {
        return AppFailure<RewardRuleEligibilityResult>(
          conditionError,
        );
      }

      final conditionState = (conditionResult as AppSuccess<TriState>).value;

      switch (conditionState) {
        case TriState.satisfied:
          break;

        case TriState.notSatisfied:
        case TriState.notApplicable:
          return AppSuccess<RewardRuleEligibilityResult>(
            RewardRuleEligibilityResult.ineligible(
              ruleId: rule.id,
              reasonCodes: const <RewardReasonCode>[
                RewardReasonCode.conditionNotSatisfied,
              ],
            ),
          );

        case TriState.unknown:
          return AppSuccess<RewardRuleEligibilityResult>(
            RewardRuleEligibilityResult.unavailable(
              ruleId: rule.id,
              confidence: RewardConfidence.conditional,
              reasonCodes: const <RewardReasonCode>[
                RewardReasonCode.conditionUnknown,
              ],
            ),
          );
      }
    }

    return AppSuccess<RewardRuleEligibilityResult>(
      RewardRuleEligibilityResult.eligible(ruleId: rule.id),
    );
  }

  AppResult<RewardRuleEvaluationResult> evaluate({
    required RewardRule rule,
    required RewardEvaluationInput input,
  }) {
    if (input.amount.isNegative) {
      return _failure(
        rule: rule,
        code: AppErrorCode.calculationInputInvalid,
        field: 'amount',
        safeMessage: 'The transaction amount must not be negative.',
      );
    }

    if (_matchesAnyAxis(rule.exclusions, input)) {
      return AppSuccess<RewardRuleEvaluationResult>(
        RewardRuleEvaluationResult.ineligible(
          ruleId: rule.id,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.excluded,
          ],
        ),
      );
    }

    if (!_matchesAllAxes(rule.selectors, input)) {
      return AppSuccess<RewardRuleEvaluationResult>(
        RewardRuleEvaluationResult.ineligible(
          ruleId: rule.id,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.selectorMismatch,
          ],
        ),
      );
    }

    final evaluationDate = input.dateFor(rule.dateBasis);
    if (evaluationDate == null) {
      return AppSuccess<RewardRuleEvaluationResult>(
        RewardRuleEvaluationResult.unavailable(
          ruleId: rule.id,
          confidence: RewardConfidence.unknown,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.missingDateBasis,
          ],
        ),
      );
    }

    if (!rule.validityPeriod.contains(evaluationDate)) {
      return AppSuccess<RewardRuleEvaluationResult>(
        RewardRuleEvaluationResult.ineligible(
          ruleId: rule.id,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.outsideValidityPeriod,
          ],
        ),
      );
    }

    final conditionExpression = rule.conditionExpression;
    if (conditionExpression != null) {
      final conditionResult = _conditionEvaluator.evaluate(
        conditionExpression,
        input.conditionContext,
      );

      if (conditionResult
          case AppFailure<TriState>(error: final conditionError)) {
        return AppFailure<RewardRuleEvaluationResult>(conditionError);
      }

      final conditionState = (conditionResult as AppSuccess<TriState>).value;

      switch (conditionState) {
        case TriState.satisfied:
          break;

        case TriState.notSatisfied:
        case TriState.notApplicable:
          return AppSuccess<RewardRuleEvaluationResult>(
            RewardRuleEvaluationResult.ineligible(
              ruleId: rule.id,
              reasonCodes: const <RewardReasonCode>[
                RewardReasonCode.conditionNotSatisfied,
              ],
            ),
          );

        case TriState.unknown:
          return AppSuccess<RewardRuleEvaluationResult>(
            RewardRuleEvaluationResult.unavailable(
              ruleId: rule.id,
              confidence: RewardConfidence.conditional,
              reasonCodes: const <RewardReasonCode>[
                RewardReasonCode.conditionUnknown,
              ],
            ),
          );
      }
    }

    final calculationResult = _calculationEvaluator.evaluateResult(
      calculation: rule.calculation,
      amount: input.amount,
      periodSnapshot: input.thresholdPeriodSnapshot,
    );

    return switch (calculationResult) {
      AppSuccess(value: final calculation) =>
        AppSuccess<RewardRuleEvaluationResult>(
          RewardRuleEvaluationResult.fromCalculation(
            ruleId: rule.id,
            calculation: calculation,
          ),
        ),
      AppFailure(error: final error) =>
        AppFailure<RewardRuleEvaluationResult>(error),
    };
  }

  bool _matchesAllAxes(
    SelectorSet selectors,
    RewardEvaluationInput input,
  ) {
    return _requiredSingleMatch(
          selectors.instrumentIds,
          input.instrumentId,
        ) &&
        _requiredSingleMatch(selectors.modeIds, input.modeId) &&
        _requiredSingleMatch(selectors.routeIds, input.routeId) &&
        _requiredMultipleMatch(
          selectors.fundingRelationIds,
          input.fundingRelationIds,
        ) &&
        _requiredSingleMatch(selectors.merchantIds, input.merchantId) &&
        _requiredMultipleMatch(
          selectors.merchantGroupIds,
          input.merchantGroupIds,
        ) &&
        _requiredMultipleMatch(selectors.categoryIds, input.categoryIds) &&
        _requiredMultipleMatch(selectors.brandIds, input.brandIds) &&
        _requiredMultipleMatch(selectors.locationIds, input.locationIds) &&
        _requiredMultipleMatch(
          selectors.transactionTags,
          input.transactionTags,
        );
  }

  bool _matchesAnyAxis(
    SelectorSet exclusions,
    RewardEvaluationInput input,
  ) {
    return _optionalSingleMatch(
          exclusions.instrumentIds,
          input.instrumentId,
        ) ||
        _optionalSingleMatch(exclusions.modeIds, input.modeId) ||
        _optionalSingleMatch(exclusions.routeIds, input.routeId) ||
        _optionalMultipleMatch(
          exclusions.fundingRelationIds,
          input.fundingRelationIds,
        ) ||
        _optionalSingleMatch(exclusions.merchantIds, input.merchantId) ||
        _optionalMultipleMatch(
          exclusions.merchantGroupIds,
          input.merchantGroupIds,
        ) ||
        _optionalMultipleMatch(exclusions.categoryIds, input.categoryIds) ||
        _optionalMultipleMatch(exclusions.brandIds, input.brandIds) ||
        _optionalMultipleMatch(exclusions.locationIds, input.locationIds) ||
        _optionalMultipleMatch(
          exclusions.transactionTags,
          input.transactionTags,
        );
  }

  bool _requiredSingleMatch(
    List<StableId> expected,
    StableId? actual,
  ) {
    return expected.isEmpty || actual != null && expected.contains(actual);
  }

  bool _requiredMultipleMatch(
    List<StableId> expected,
    List<StableId> actual,
  ) {
    return expected.isEmpty || actual.any(expected.contains);
  }

  bool _optionalSingleMatch(
    List<StableId> expected,
    StableId? actual,
  ) {
    return expected.isNotEmpty && actual != null && expected.contains(actual);
  }

  bool _optionalMultipleMatch(
    List<StableId> expected,
    List<StableId> actual,
  ) {
    return expected.isNotEmpty && actual.any(expected.contains);
  }

  AppFailure<T> _failure<T>({
    required RewardRule rule,
    required AppErrorCode code,
    required String field,
    required String safeMessage,
  }) {
    return AppFailure<T>(
      AppError(
        code: code,
        operation: _operation,
        context: <String, Object?>{
          'ruleId': rule.id.value,
          'field': field,
        },
        safeMessage: safeMessage,
      ),
    );
  }
}

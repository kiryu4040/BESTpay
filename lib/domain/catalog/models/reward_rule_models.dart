import '../../../core/value_objects/calculation_date.dart';
import '../../../core/value_objects/money_yen.dart';
import '../../../core/value_objects/point_amount.dart';
import '../../../core/value_objects/rational.dart';
import '../../../core/value_objects/rounding_mode.dart';
import '../../../core/value_objects/stable_id.dart';
import '../../../core/value_objects/validity_period.dart';
import 'catalog_entity.dart';
import 'catalog_types.dart';
import 'condition_models.dart';

/// Typed include/exclude selectors used by a reward rule.
final class SelectorSet {
  SelectorSet({
    required Iterable<StableId> instrumentIds,
    required Iterable<StableId> modeIds,
    required Iterable<StableId> routeIds,
    required Iterable<StableId> fundingRelationIds,
    required Iterable<StableId> merchantIds,
    required Iterable<StableId> merchantGroupIds,
    required Iterable<StableId> categoryIds,
    required Iterable<StableId> brandIds,
    required Iterable<StableId> locationIds,
    required Iterable<StableId> transactionTags,
  })  : instrumentIds = _freezeUniqueIds(instrumentIds, 'instrumentIds'),
        modeIds = _freezeUniqueIds(modeIds, 'modeIds'),
        routeIds = _freezeUniqueIds(routeIds, 'routeIds'),
        fundingRelationIds = _freezeUniqueIds(
          fundingRelationIds,
          'fundingRelationIds',
        ),
        merchantIds = _freezeUniqueIds(merchantIds, 'merchantIds'),
        merchantGroupIds = _freezeUniqueIds(
          merchantGroupIds,
          'merchantGroupIds',
        ),
        categoryIds = _freezeUniqueIds(categoryIds, 'categoryIds'),
        brandIds = _freezeUniqueIds(brandIds, 'brandIds'),
        locationIds = _freezeUniqueIds(locationIds, 'locationIds'),
        transactionTags = _freezeUniqueIds(
          transactionTags,
          'transactionTags',
        );

  final List<StableId> instrumentIds;
  final List<StableId> modeIds;
  final List<StableId> routeIds;
  final List<StableId> fundingRelationIds;
  final List<StableId> merchantIds;
  final List<StableId> merchantGroupIds;
  final List<StableId> categoryIds;
  final List<StableId> brandIds;
  final List<StableId> locationIds;
  final List<StableId> transactionTags;
}

/// A reward calculation definition. PR-07 does not execute calculations.
sealed class RewardCalculation {
  const RewardCalculation();
}

final class UnitPointsRewardCalculation extends RewardCalculation {
  UnitPointsRewardCalculation({
    required this.amountUnit,
    required this.pointsPerUnit,
    required this.rounding,
  }) {
    if (amountUnit.yen < 1) {
      throw ArgumentError.value(
        amountUnit,
        'amountUnit',
        'Amount unit must be at least one yen.',
      );
    }
  }

  final MoneyYen amountUnit;
  final PointAmount pointsPerUnit;
  final RoundingMode rounding;
}

final class RateFractionRewardCalculation extends RewardCalculation {
  const RateFractionRewardCalculation({
    required this.rate,
    required this.rounding,
  });

  final Rational rate;
  final RoundingMode rounding;
}

final class FixedPointsRewardCalculation extends RewardCalculation {
  const FixedPointsRewardCalculation(this.points);

  final PointAmount points;
}

final class MirrorRewardCalculation extends RewardCalculation {
  const MirrorRewardCalculation({
    required this.sourceRuleId,
    required this.multiplier,
    required this.inheritEligibility,
    required this.inheritExclusions,
    required this.useFinalSourceAmount,
  });

  final StableId sourceRuleId;
  final Rational multiplier;
  final bool inheritEligibility;
  final bool inheritExclusions;
  final bool useFinalSourceAmount;
}

final class ThresholdBonusRewardCalculation extends RewardCalculation {
  ThresholdBonusRewardCalculation({
    required this.thresholdAmount,
    required this.bonusPoints,
    required this.maxAwardsPerPeriod,
  }) {
    if (thresholdAmount.isNegative) {
      throw ArgumentError.value(
        thresholdAmount,
        'thresholdAmount',
        'Threshold amount must not be negative.',
      );
    }
    if (maxAwardsPerPeriod < 1) {
      throw ArgumentError.value(
        maxAwardsPerPeriod,
        'maxAwardsPerPeriod',
        'Maximum awards must be at least one.',
      );
    }
  }

  final MoneyYen thresholdAmount;
  final PointAmount bonusPoints;
  final int maxAwardsPerPeriod;
}

final class TieredRewardCalculation extends RewardCalculation {
  TieredRewardCalculation(Iterable<RewardTier> tiers)
      : tiers = List<RewardTier>.unmodifiable(tiers) {
    if (this.tiers.isEmpty) {
      throw ArgumentError.value(
        tiers,
        'tiers',
        'At least one tier is required.',
      );
    }
  }

  final List<RewardTier> tiers;
}

final class NoRewardCalculation extends RewardCalculation {
  const NoRewardCalculation();
}

/// One amount interval in a tiered reward calculation.
final class RewardTier {
  RewardTier({
    required this.minimumAmount,
    required this.maximumAmountExclusive,
    required this.calculation,
  }) {
    if (minimumAmount.isNegative) {
      throw ArgumentError.value(
        minimumAmount,
        'minimumAmount',
        'Minimum amount must not be negative.',
      );
    }
    if (maximumAmountExclusive != null && maximumAmountExclusive!.yen < 1) {
      throw ArgumentError.value(
        maximumAmountExclusive,
        'maximumAmountExclusive',
        'Maximum amount must be positive.',
      );
    }
    if (calculation is! UnitPointsRewardCalculation &&
        calculation is! RateFractionRewardCalculation &&
        calculation is! FixedPointsRewardCalculation) {
      throw ArgumentError.value(
        calculation,
        'calculation',
        'Tier calculations must be unit-points, rate, or fixed-points.',
      );
    }
  }

  final MoneyYen minimumAmount;
  final MoneyYen? maximumAmountExclusive;
  final RewardCalculation calculation;
}

/// Aggregation metadata retained for later reward evaluation.
final class RewardAggregation {
  RewardAggregation({
    required this.scope,
    required this.aggregationKey,
    required this.periodMinimumEligibleSpend,
    required this.conditionEvaluationTiming,
    required this.incrementalAward,
  }) {
    if (periodMinimumEligibleSpend.isNegative) {
      throw ArgumentError.value(
        periodMinimumEligibleSpend,
        'periodMinimumEligibleSpend',
        'Minimum eligible spend must not be negative.',
      );
    }
    _requireNonEmpty(
      conditionEvaluationTiming,
      'conditionEvaluationTiming',
    );
  }

  final RewardAggregationScope scope;
  final StableId? aggregationKey;
  final MoneyYen periodMinimumEligibleSpend;
  final String conditionEvaluationTiming;
  final bool incrementalAward;
}

/// Stacking relationships retained for later reward evaluation.
final class RewardStacking {
  RewardStacking({
    required this.policy,
    required this.exclusiveGroupId,
    required Iterable<StableId> replacesRuleIds,
    required Iterable<StableId> suppressesRuleIds,
    required Iterable<StableId> suppressesTags,
    required Iterable<StableId> dependsOnRuleIds,
    required this.applicationOrder,
  })  : replacesRuleIds = _freezeUniqueIds(
          replacesRuleIds,
          'replacesRuleIds',
        ),
        suppressesRuleIds = _freezeUniqueIds(
          suppressesRuleIds,
          'suppressesRuleIds',
        ),
        suppressesTags = _freezeUniqueIds(
          suppressesTags,
          'suppressesTags',
        ),
        dependsOnRuleIds = _freezeUniqueIds(
          dependsOnRuleIds,
          'dependsOnRuleIds',
        ) {
    _requireNonEmpty(policy, 'policy');
  }

  final String policy;
  final StableId? exclusiveGroupId;
  final List<StableId> replacesRuleIds;
  final List<StableId> suppressesRuleIds;
  final List<StableId> suppressesTags;
  final List<StableId> dependsOnRuleIds;
  final int applicationOrder;
}

/// An optional reward limit. Its open strings are not invented as enums.
final class RewardCap {
  RewardCap({
    required this.capType,
    required this.limit,
    required this.periodType,
    required this.scopeKey,
    required this.appliesTo,
    required this.overflowPolicy,
  }) {
    _requireNonEmpty(capType, 'capType');
    _requireNonEmpty(periodType, 'periodType');
    _requireNonEmpty(appliesTo, 'appliesTo');
    _requireNonEmpty(overflowPolicy, 'overflowPolicy');

    if (limit < 0) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Cap limit must not be negative.',
      );
    }
  }

  final String capType;
  final int limit;
  final String periodType;
  final StableId? scopeKey;
  final String appliesTo;
  final String overflowPolicy;
}

/// A complete typed reward-rule definition.
final class RewardRule implements CatalogEntity {
  RewardRule({
    required this.id,
    required this.name,
    required this.description,
    required this.ruleKind,
    required this.selectors,
    required this.exclusions,
    required this.conditionExpression,
    required this.calculation,
    required this.outputPointProgramId,
    required this.aggregation,
    required this.stacking,
    required this.cap,
    required this.validityPeriod,
    required this.dateBasis,
    required this.timezone,
    required this.displayClaim,
    required Iterable<StableId> sourceIds,
    required this.lastVerifiedAt,
    required this.status,
    required this.priority,
    required Iterable<StableId> tags,
    required Iterable<String> notes,
  })  : sourceIds = _freezeUniqueIds(sourceIds, 'sourceIds'),
        tags = _freezeUniqueIds(tags, 'tags'),
        notes = _freezeUniqueText(notes, 'notes') {
    _requireNonEmpty(name, 'name');

    if (timezone != 'Asia/Tokyo') {
      throw ArgumentError.value(
        timezone,
        'timezone',
        'Reward rules must use Asia/Tokyo.',
      );
    }

    if (displayClaim != null) {
      _requireNonEmpty(displayClaim!, 'displayClaim');
    }
  }

  @override
  final StableId id;
  final String name;

  /// May be empty because the schema does not define a minimum length.
  final String description;

  final RewardRuleKind ruleKind;
  final SelectorSet selectors;
  final SelectorSet exclusions;
  final ConditionExpression? conditionExpression;
  final RewardCalculation calculation;
  final StableId? outputPointProgramId;
  final RewardAggregation aggregation;
  final RewardStacking stacking;
  final RewardCap? cap;
  final ValidityPeriod validityPeriod;
  final RewardDateBasis dateBasis;
  final String timezone;
  final String? displayClaim;
  final List<StableId> sourceIds;
  final CalculationDate lastVerifiedAt;
  final CatalogItemStatus status;
  final int priority;
  final List<StableId> tags;
  final List<String> notes;
}

List<StableId> _freezeUniqueIds(
  Iterable<StableId> values,
  String fieldName,
) {
  final result = List<StableId>.of(values);

  if (result.toSet().length != result.length) {
    throw ArgumentError.value(
      values,
      fieldName,
      'Values must be unique.',
    );
  }

  return List<StableId>.unmodifiable(result);
}

List<String> _freezeUniqueText(
  Iterable<String> values,
  String fieldName,
) {
  final result = List<String>.of(values);

  for (final value in result) {
    _requireNonEmpty(value, fieldName);
  }

  if (result.toSet().length != result.length) {
    throw ArgumentError.value(
      values,
      fieldName,
      'Values must be unique.',
    );
  }

  return List<String>.unmodifiable(result);
}

void _requireNonEmpty(String value, String fieldName) {
  if (value.isEmpty) {
    throw ArgumentError.value(
      value,
      fieldName,
      'Value must not be empty.',
    );
  }
}

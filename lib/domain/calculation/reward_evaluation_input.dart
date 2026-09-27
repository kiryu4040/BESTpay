import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/calculation/period_aggregation_snapshot.dart';
import 'package:bestpay/domain/calculation/threshold_period_snapshot.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';

/// Immutable transaction and state input for reward-rule evaluation.
final class RewardEvaluationInput {
  RewardEvaluationInput({
    required this.amount,
    required this.instrumentId,
    required this.modeId,
    required this.routeId,
    Iterable<StableId> fundingRelationIds = const <StableId>[],
    required this.merchantId,
    Iterable<StableId> merchantGroupIds = const <StableId>[],
    Iterable<StableId> categoryIds = const <StableId>[],
    Iterable<StableId> brandIds = const <StableId>[],
    Iterable<StableId> locationIds = const <StableId>[],
    Iterable<StableId> transactionTags = const <StableId>[],
    this.transactionDate,
    this.postingDate,
    this.settlementDataReceivedDate,
    this.billingDate,
    this.entryDate,
    this.campaignRegistrationDate,
    this.periodEndDate,
    required this.conditionContext,
    this.thresholdPeriodSnapshot,
    Map<StableId, PeriodAggregationSnapshot> periodAggregationSnapshots =
        const <StableId, PeriodAggregationSnapshot>{},
  })  : fundingRelationIds = List<StableId>.unmodifiable(fundingRelationIds),
        merchantGroupIds = List<StableId>.unmodifiable(merchantGroupIds),
        categoryIds = List<StableId>.unmodifiable(categoryIds),
        brandIds = List<StableId>.unmodifiable(brandIds),
        locationIds = List<StableId>.unmodifiable(locationIds),
        transactionTags = List<StableId>.unmodifiable(transactionTags),
        periodAggregationSnapshots =
            _freezePeriodAggregationSnapshots(periodAggregationSnapshots);

  final MoneyYen amount;
  final StableId? instrumentId;
  final StableId? modeId;
  final StableId? routeId;
  final List<StableId> fundingRelationIds;
  final StableId? merchantId;
  final List<StableId> merchantGroupIds;
  final List<StableId> categoryIds;
  final List<StableId> brandIds;
  final List<StableId> locationIds;
  final List<StableId> transactionTags;

  final CalculationDate? transactionDate;
  final CalculationDate? postingDate;
  final CalculationDate? settlementDataReceivedDate;
  final CalculationDate? billingDate;
  final CalculationDate? entryDate;
  final CalculationDate? campaignRegistrationDate;
  final CalculationDate? periodEndDate;

  final ConditionEvaluationContext conditionContext;
  final ThresholdPeriodSnapshot? thresholdPeriodSnapshot;
  final Map<StableId, PeriodAggregationSnapshot> periodAggregationSnapshots;

  CalculationDate? dateFor(RewardDateBasis basis) {
    return switch (basis) {
      RewardDateBasis.transactionDate => transactionDate,
      RewardDateBasis.postingDate => postingDate,
      RewardDateBasis.settlementDataReceivedDate => settlementDataReceivedDate,
      RewardDateBasis.billingDate => billingDate,
      RewardDateBasis.entryDate => entryDate,
      RewardDateBasis.campaignRegistrationDate => campaignRegistrationDate,
      RewardDateBasis.periodEndDate => periodEndDate,
    };
  }

  PeriodAggregationSnapshot? periodAggregationSnapshotFor(
    StableId aggregationKey,
  ) {
    return periodAggregationSnapshots[aggregationKey];
  }
}

Map<StableId, PeriodAggregationSnapshot> _freezePeriodAggregationSnapshots(
  Map<StableId, PeriodAggregationSnapshot> values,
) {
  return Map<StableId, PeriodAggregationSnapshot>.unmodifiable(
    Map<StableId, PeriodAggregationSnapshot>.of(values),
  );
}

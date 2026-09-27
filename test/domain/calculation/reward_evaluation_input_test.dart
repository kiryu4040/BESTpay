import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/calculation/reward_evaluation_input.dart';
import 'package:bestpay/domain/calculation/threshold_period_snapshot.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RewardEvaluationInput', () {
    test('returns the date selected by every RewardDateBasis', () {
      final dates = <RewardDateBasis, CalculationDate>{
        RewardDateBasis.transactionDate: _date('2026-01-01'),
        RewardDateBasis.postingDate: _date('2026-01-02'),
        RewardDateBasis.settlementDataReceivedDate: _date('2026-01-03'),
        RewardDateBasis.billingDate: _date('2026-01-04'),
        RewardDateBasis.entryDate: _date('2026-01-05'),
        RewardDateBasis.campaignRegistrationDate: _date('2026-01-06'),
        RewardDateBasis.periodEndDate: _date('2026-01-07'),
      };

      final input = RewardEvaluationInput(
        amount: const MoneyYen(1000),
        instrumentId: null,
        modeId: null,
        routeId: null,
        merchantId: null,
        transactionDate: dates[RewardDateBasis.transactionDate],
        postingDate: dates[RewardDateBasis.postingDate],
        settlementDataReceivedDate:
            dates[RewardDateBasis.settlementDataReceivedDate],
        billingDate: dates[RewardDateBasis.billingDate],
        entryDate: dates[RewardDateBasis.entryDate],
        campaignRegistrationDate:
            dates[RewardDateBasis.campaignRegistrationDate],
        periodEndDate: dates[RewardDateBasis.periodEndDate],
        conditionContext: ConditionEvaluationContext(),
      );

      for (final entry in dates.entries) {
        expect(input.dateFor(entry.key), entry.value);
      }
    });

    test('returns null when the selected date is missing', () {
      final input = _emptyInput();

      expect(
        input.dateFor(RewardDateBasis.postingDate),
        isNull,
      );
    });

    test('defensively copies and freezes all multi-value selectors', () {
      final first = _id('selector_one');
      final second = _id('selector_two');
      final values = <StableId>[first];

      final input = RewardEvaluationInput(
        amount: const MoneyYen(1000),
        instrumentId: null,
        modeId: null,
        routeId: null,
        fundingRelationIds: values,
        merchantId: null,
        merchantGroupIds: values,
        categoryIds: values,
        brandIds: values,
        locationIds: values,
        transactionTags: values,
        conditionContext: ConditionEvaluationContext(),
      );

      values.add(second);

      for (final frozen in <List<StableId>>[
        input.fundingRelationIds,
        input.merchantGroupIds,
        input.categoryIds,
        input.brandIds,
        input.locationIds,
        input.transactionTags,
      ]) {
        expect(frozen, <StableId>[first]);
        expect(
          () => frozen.add(second),
          throwsUnsupportedError,
        );
      }
    });

    test('retains condition and threshold snapshot references', () {
      final conditionContext = ConditionEvaluationContext();
      final snapshot = ThresholdPeriodSnapshot.validated(
        periodSpendBefore: const MoneyYen(900),
        awardsConsumed: 0,
      );

      final input = RewardEvaluationInput(
        amount: const MoneyYen(100),
        instrumentId: _id('instrument_one'),
        modeId: _id('mode_one'),
        routeId: _id('route_one'),
        merchantId: _id('merchant_one'),
        conditionContext: conditionContext,
        thresholdPeriodSnapshot: snapshot,
      );

      expect(input.conditionContext, same(conditionContext));
      expect(input.thresholdPeriodSnapshot, same(snapshot));
    });
  });
}

RewardEvaluationInput _emptyInput() {
  return RewardEvaluationInput(
    amount: MoneyYen.zero,
    instrumentId: null,
    modeId: null,
    routeId: null,
    merchantId: null,
    conditionContext: ConditionEvaluationContext(),
  );
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

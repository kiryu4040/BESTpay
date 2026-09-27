import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/calculation/period_aggregation_snapshot.dart';
import 'package:bestpay/domain/calculation/reward_evaluation_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PeriodAggregationSnapshot', () {
    test('retains a valid immutable period state', () {
      final snapshot = PeriodAggregationSnapshot.validated(
        periodStart: _date('2026-06-01'),
        periodEndExclusive: _date('2026-07-01'),
        periodSpendBefore: const MoneyYen(1000),
        periodSpendAfter: const MoneyYen(1500),
        pointsBefore: const PointAmount(10),
        pointsAfter: const PointAmount(15),
        currentIncrement: const PointAmount(5),
        confidence: PeriodDataConfidence.exact,
      );

      expect(snapshot.periodSpendBefore, const MoneyYen(1000));
      expect(snapshot.periodSpendAfter, const MoneyYen(1500));
      expect(snapshot.pointsBefore, const PointAmount(10));
      expect(snapshot.pointsAfter, const PointAmount(15));
      expect(snapshot.currentIncrement, const PointAmount(5));
      expect(snapshot.confidence, PeriodDataConfidence.exact);
    });

    test('accepts every period data confidence value', () {
      for (final confidence in PeriodDataConfidence.values) {
        final snapshot = _snapshot(confidence: confidence);

        expect(snapshot.confidence, confidence);
      }
    });

    test('allows a negative current increment when totals are consistent', () {
      final snapshot = PeriodAggregationSnapshot.validated(
        periodStart: _date('2026-06-01'),
        periodEndExclusive: _date('2026-07-01'),
        periodSpendBefore: const MoneyYen(2000),
        periodSpendAfter: const MoneyYen(1500),
        pointsBefore: const PointAmount(20),
        pointsAfter: const PointAmount(15),
        currentIncrement: const PointAmount(-5),
        confidence: PeriodDataConfidence.exact,
      );

      expect(snapshot.currentIncrement, const PointAmount(-5));
    });

    test('rejects negative period spend totals', () {
      expect(
        () => PeriodAggregationSnapshot.validated(
          periodStart: _date('2026-06-01'),
          periodEndExclusive: _date('2026-07-01'),
          periodSpendBefore: const MoneyYen(-1),
          periodSpendAfter: MoneyYen.zero,
          pointsBefore: PointAmount.zero,
          pointsAfter: PointAmount.zero,
          currentIncrement: PointAmount.zero,
          confidence: PeriodDataConfidence.exact,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => PeriodAggregationSnapshot.validated(
          periodStart: _date('2026-06-01'),
          periodEndExclusive: _date('2026-07-01'),
          periodSpendBefore: MoneyYen.zero,
          periodSpendAfter: const MoneyYen(-1),
          pointsBefore: PointAmount.zero,
          pointsAfter: PointAmount.zero,
          currentIncrement: PointAmount.zero,
          confidence: PeriodDataConfidence.exact,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects negative before or after point totals', () {
      expect(
        () => PeriodAggregationSnapshot.validated(
          periodStart: _date('2026-06-01'),
          periodEndExclusive: _date('2026-07-01'),
          periodSpendBefore: MoneyYen.zero,
          periodSpendAfter: MoneyYen.zero,
          pointsBefore: const PointAmount(-1),
          pointsAfter: PointAmount.zero,
          currentIncrement: const PointAmount(1),
          confidence: PeriodDataConfidence.exact,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => PeriodAggregationSnapshot.validated(
          periodStart: _date('2026-06-01'),
          periodEndExclusive: _date('2026-07-01'),
          periodSpendBefore: MoneyYen.zero,
          periodSpendAfter: MoneyYen.zero,
          pointsBefore: PointAmount.zero,
          pointsAfter: const PointAmount(-1),
          currentIncrement: const PointAmount(-1),
          confidence: PeriodDataConfidence.exact,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects an increment inconsistent with before and after totals', () {
      expect(
        () => PeriodAggregationSnapshot.validated(
          periodStart: _date('2026-06-01'),
          periodEndExclusive: _date('2026-07-01'),
          periodSpendBefore: const MoneyYen(1000),
          periodSpendAfter: const MoneyYen(1500),
          pointsBefore: const PointAmount(10),
          pointsAfter: const PointAmount(15),
          currentIncrement: const PointAmount(4),
          confidence: PeriodDataConfidence.exact,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // PR09_SLICE3B_BOUNDARY_TEST
    test('uses half-open period boundaries', () {
      final snapshot = _snapshot();

      expect(snapshot.periodStart, _date('2026-06-01'));
      expect(snapshot.periodEndExclusive, _date('2026-07-01'));
      expect(snapshot.contains(_date('2026-05-31')), isFalse);
      expect(snapshot.contains(_date('2026-06-01')), isTrue);
      expect(snapshot.contains(_date('2026-06-30')), isTrue);
      expect(snapshot.contains(_date('2026-07-01')), isFalse);
    });

    // PR09_SLICE3B_BOUNDARY_TEST
    test('rejects empty and reversed period boundaries', () {
      for (final end in <CalculationDate>[
        _date('2026-06-01'),
        _date('2026-05-31'),
      ]) {
        expect(
          () => PeriodAggregationSnapshot.validated(
            periodStart: _date('2026-06-01'),
            periodEndExclusive: end,
            periodSpendBefore: MoneyYen.zero,
            periodSpendAfter: MoneyYen.zero,
            pointsBefore: PointAmount.zero,
            pointsAfter: PointAmount.zero,
            currentIncrement: PointAmount.zero,
            confidence: PeriodDataConfidence.exact,
          ),
          throwsArgumentError,
        );
      }
    });
    test('RewardEvaluationInput defensively copies and freezes snapshots', () {
      final firstKey = _id('aggregation_one');
      final secondKey = _id('aggregation_two');
      final firstSnapshot = _snapshot();
      final secondSnapshot = _snapshot(
        confidence: PeriodDataConfidence.estimated,
      );
      final values = <StableId, PeriodAggregationSnapshot>{
        firstKey: firstSnapshot,
      };

      final input = RewardEvaluationInput(
        amount: const MoneyYen(1000),
        instrumentId: null,
        modeId: null,
        routeId: null,
        merchantId: null,
        conditionContext: ConditionEvaluationContext(),
        periodAggregationSnapshots: values,
      );

      values[secondKey] = secondSnapshot;

      expect(
        input.periodAggregationSnapshots,
        <StableId, PeriodAggregationSnapshot>{
          firstKey: firstSnapshot,
        },
      );
      expect(
        input.periodAggregationSnapshotFor(firstKey),
        same(firstSnapshot),
      );
      expect(
        input.periodAggregationSnapshotFor(secondKey),
        isNull,
      );
      expect(
        () => input.periodAggregationSnapshots[secondKey] = secondSnapshot,
        throwsUnsupportedError,
      );
    });
  });
}

PeriodAggregationSnapshot _snapshot({
  PeriodDataConfidence confidence = PeriodDataConfidence.exact,
}) {
  return PeriodAggregationSnapshot.validated(
    periodStart: _date('2026-06-01'),
    periodEndExclusive: _date('2026-07-01'),
    periodSpendBefore: const MoneyYen(1000),
    periodSpendAfter: const MoneyYen(1500),
    pointsBefore: const PointAmount(10),
    pointsAfter: const PointAmount(15),
    currentIncrement: const PointAmount(5),
    confidence: confidence,
  );
}

CalculationDate _date(String value) {
  final result = CalculationDate.parse(value);
  expect(result, isA<AppSuccess<CalculationDate>>());
  return (result as AppSuccess<CalculationDate>).value;
}

StableId _id(String value) {
  final result = StableId.create(value);
  expect(result, isA<AppSuccess<StableId>>());
  return (result as AppSuccess<StableId>).value;
}

import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/rounding_mode.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:bestpay/domain/ranking/period_increment_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final calculation = UnitPointsRewardCalculation(
    amountUnit: const MoneyYen(1000),
    pointsPerUnit: const PointAmount(1),
    rounding: RoundingMode.floor,
  );

  PeriodIncrement compute(MoneyYen periodSpendBefore, MoneyYen amount) {
    final result = const PeriodIncrementCalculator().compute(
      calculation: calculation,
      periodSpendBefore: periodSpendBefore,
      amount: amount,
    );

    return result.fold(
      onSuccess: (value) => value,
      onFailure: (_) => throw StateError('計算に失敗しました。'),
    );
  }

  test('月間合算の増分: P=900, A=200, U=1000 で1単位', () {
    final increment = compute(const MoneyYen(900), const MoneyYen(200));

    expect(increment.pointsBefore.points, 0);
    expect(increment.pointsAfter.points, 1);
    expect(increment.increment.points, 1);
  });

  test('単位をまたがない場合は増分0', () {
    final increment = compose();

    expect(increment.increment.points, 0);
  });

  test('端数は切り捨てて単位分だけ増える', () {
    final increment = compute(const MoneyYen(0), const MoneyYen(1900));

    expect(increment.pointsAfter.points, 1);
    expect(increment.increment.points, 1);
  });
}

/// 抽出用の補助: P=100, A=100, U=1000 では単位をまたがない。
PeriodIncrement compose() {
  final result = const PeriodIncrementCalculator().compute(
    calculation: UnitPointsRewardCalculation(
      amountUnit: const MoneyYen(1000),
      pointsPerUnit: const PointAmount(1),
      rounding: RoundingMode.floor,
    ),
    periodSpendBefore: const MoneyYen(100),
    amount: const MoneyYen(100),
  );

  return result.fold(
    onSuccess: (value) => value,
    onFailure: (_) => throw StateError('計算に失敗しました。'),
  );
}

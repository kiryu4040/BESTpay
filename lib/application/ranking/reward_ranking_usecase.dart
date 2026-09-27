import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/ranking/reward_ranking.dart';
import 'package:bestpay/domain/ranking/reward_ranking_evaluator.dart';

/// Application entry point for the reward ranking.
///
/// Presentation layers call this use case instead of the domain evaluator
/// directly, so no calculation lives in a widget or provider (D-60).
final class RewardRankingUseCase {
  const RewardRankingUseCase({
    RewardRankingEvaluator evaluator = const RewardRankingEvaluator(),
  }) : _evaluator = evaluator;

  final RewardRankingEvaluator _evaluator;

  /// Compares every catalog card for one transaction of [amount] at
  /// [transactionDate] against the baseline card (D-084, D-085).
  ///
  /// 月間・年間の集計額は一切受け取らない。判定は1回の支払い単独で完結する。
  RewardRanking execute({
    required Catalog catalog,
    required MoneyYen amount,
    required CalculationDate transactionDate,
    ConditionEvaluationContext? conditionContext,
    StableId? merchantId,
    Iterable<StableId> merchantGroupIds = const <StableId>[],
    Iterable<StableId> categoryIds = const <StableId>[],
  }) {
    return _evaluator.evaluate(
      catalog: catalog,
      amount: amount,
      transactionDate: transactionDate,
      conditionContext: conditionContext,
      merchantId: merchantId,
      merchantGroupIds: merchantGroupIds,
      categoryIds: categoryIds,
    );
  }

  /// 店舗を選んだだけで判定するときの比較金額（D-090）。
  ///
  /// レジ前で金額を入力させないため、比較は還元率で行う。還元率は
  /// カードごとの計算単位（100円・200円・1,000円）で割り切れる金額で
  /// 評価すれば端数処理の影響を受けないため、1万円を内部の基準額に使う。
  static const MoneyYen comparisonAmount = MoneyYen(10000);
}

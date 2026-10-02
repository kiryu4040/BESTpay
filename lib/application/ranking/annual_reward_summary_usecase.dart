import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:bestpay/domain/ranking/reward_ranking.dart';
import 'package:bestpay/domain/ranking/reward_ranking_evaluator.dart';

/// カード1枚の年間概算（D-102）。
final class AnnualRewardEntry {
  const AnnualRewardEntry({
    required this.instrumentId,
    required this.instrumentName,
    required this.annualFee,
    required this.baseValue,
    required this.bonusValue,
    required this.totalValue,
    required this.effectiveRate,
    required this.feeWaivedNextYear,
    required this.hasUnresolvedConditions,
  });

  final StableId instrumentId;
  final String instrumentName;
  final MoneyYen annualFee;

  /// 利用額から計算した基本還元（年間利用額をまとめて1回の計算として評価）。
  final MicrosYen baseValue;

  /// 100万円などの到達で得られる年間ボーナス。
  final MicrosYen bonusValue;

  final MicrosYen totalValue;
  final Rational effectiveRate;

  /// 年間の到達条件を満たし、翌年以降の年会費が無料になるか。
  final bool feeWaivedNextYear;

  final bool hasUnresolvedConditions;
}

/// 年間タブの集計結果。
final class AnnualRewardSummary {
  AnnualRewardSummary({
    required this.annualSpend,
    required Iterable<AnnualRewardEntry> entries,
  }) : entries = List<AnnualRewardEntry>.unmodifiable(entries);

  final MoneyYen annualSpend;
  final List<AnnualRewardEntry> entries;

  /// 合計額の多い順。
  List<AnnualRewardEntry> get ordered {
    final sorted = entries.toList()
      ..sort(
        (left, right) => right.totalValue
            .compareTo(left.totalValue),
      );

    return sorted;
  }
}

/// 年間の還元額をカードごとに概算する（D-102）。
///
/// 年間利用額は利用者が入力する（金額入力はこのタブだけ・D-088）。
/// 基本還元は「年間利用額をまとめて1回計算した」概算である。取引単位・月単位で
/// 端数を切り捨てる制度では、実際の獲得ポイントを上回る場合がある
/// （例: 200円1ポイント・取引ごと切り捨ての制度で199円を2回払うと実際は0ptだが、
/// 合計398円を1回とみなすと1ptになる）。
///
/// したがって、この結果は「端数処理・利用先・利用時期に依存する概算」であり、
/// 実際の年間獲得額を確定したものではない。
final class AnnualRewardSummaryUseCase {
  const AnnualRewardSummaryUseCase({
    RewardRankingEvaluator evaluator = const RewardRankingEvaluator(),
  }) : _evaluator = evaluator;

  final RewardRankingEvaluator _evaluator;

  AnnualRewardSummary execute({
    required Catalog catalog,
    required MoneyYen annualSpend,
    required CalculationDate transactionDate,
    ConditionEvaluationContext? conditionContext,
    Set<String> hiddenCardIds = const <String>{},
  }) {
    final context = conditionContext ?? ConditionEvaluationContext();
    final ranking = _evaluator.evaluate(
      catalog: catalog,
      amount: annualSpend,
      transactionDate: transactionDate,
      conditionContext: context,
    );

    final entries = <AnnualRewardEntry>[];
    for (final entry in ranking.allEntries) {
      if (hiddenCardIds.contains(entry.instrumentId.value)) {
        continue;
      }

      final bonus = _bonusFor(
        catalog: catalog,
        instrumentId: entry.instrumentId,
        annualSpend: annualSpend,
        transactionDate: transactionDate,
      );

      final total = entry.confirmedValue + bonus.value;

      entries.add(
        AnnualRewardEntry(
          instrumentId: entry.instrumentId,
          instrumentName: entry.instrumentName,
          annualFee: entry.annualFee,
          baseValue: entry.confirmedValue,
          bonusValue: bonus.value,
          totalValue: total,
          effectiveRate: _rate(total, annualSpend),
          feeWaivedNextYear: bonus.waivesFee,
          hasUnresolvedConditions: entry.hasUnresolvedConditions,
        ),
      );
    }

    return AnnualRewardSummary(annualSpend: annualSpend, entries: entries);
  }

  /// 年間の到達ボーナス（100万円で10,000ptなど）をカタログから直接合計する。
  ///
  /// 有効期間外のルールは加算しない（AUD-03）。条件式をもつボーナスは、
  /// この経路では達成状況を判定しないため確定加算しない（不明分は足さない・D-50）。
  /// 年会費免除はポイントボーナスとは別の判定とし、明示的なタグ
  /// `annual_fee_waiver` をもつルールだけを根拠にする。
  _AnnualBonus _bonusFor({
    required Catalog catalog,
    required StableId instrumentId,
    required MoneyYen annualSpend,
    required CalculationDate transactionDate,
  }) {
    var valueMicros = 0;
    var waivesFee = false;

    for (final rule in catalog.rewardRulesById.values) {
      if (rule.status == CatalogItemStatus.draft) {
        continue;
      }

      if (rule.selectors.categoryIds.isNotEmpty ||
          rule.selectors.merchantIds.isNotEmpty ||
          rule.selectors.merchantGroupIds.isNotEmpty) {
        continue;
      }

      if (!rule.selectors.instrumentIds.contains(instrumentId)) {
        continue;
      }

      if (!rule.validityPeriod.contains(transactionDate)) {
        continue;
      }

      if (rule.conditionExpression != null) {
        continue;
      }

      final calculation = rule.calculation;
      if (calculation is! ThresholdBonusRewardCalculation) {
        continue;
      }

      if (annualSpend < calculation.thresholdAmount) {
        continue;
      }

      if (rule.tags.contains('annual_fee_waiver')) {
        waivesFee = true;
      }

      final program = catalog.pointProgramsById[rule.outputPointProgramId];
      final converted = program?.valueOf(calculation.bonusPoints);
      if (converted != null) {
        valueMicros += converted.micros;
      }
    }

    return _AnnualBonus(value: MicrosYen(valueMicros), waivesFee: waivesFee);
  }

  Rational _rate(MicrosYen total, MoneyYen annualSpend) {
    if (annualSpend.yen <= 0) {
      return Rational.zero;
    }

    return Rational.create(
      total.micros,
      annualSpend.yen * MicrosYen.microsPerYen,
    ).fold(
      onSuccess: (value) => value,
      onFailure: (_) => Rational.zero,
    );
  }
}

final class _AnnualBonus {
  const _AnnualBonus({required this.value, required this.waivesFee});

  final MicrosYen value;
  final bool waivesFee;
}

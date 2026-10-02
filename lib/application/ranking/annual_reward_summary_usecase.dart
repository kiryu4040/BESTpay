import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:bestpay/domain/ranking/reward_ranking_evaluator.dart';

/// カード1枚の年間集計（D-102・D-160）。
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
    this.isExact = false,
  });

  final StableId instrumentId;
  final String instrumentName;
  final MoneyYen annualFee;

  /// 利用額から計算した基本還元。取引が渡された場合は実際の取引から積み上げた値。
  final MicrosYen baseValue;

  /// 100万円などの到達で得られる年間ボーナス。
  final MicrosYen bonusValue;

  final MicrosYen totalValue;
  final Rational effectiveRate;

  /// 年間の到達条件を満たし、翌年以降の年会費が無料になるか。
  final bool feeWaivedNextYear;

  final bool hasUnresolvedConditions;

  /// 実際の取引から積み上げた確定値か（false は概算）。
  final bool isExact;
}

/// 年間タブの集計結果。
final class AnnualRewardSummary {
  AnnualRewardSummary({
    required this.annualSpend,
    required Iterable<AnnualRewardEntry> entries,
    this.isExact = false,
  }) : entries = List<AnnualRewardEntry>.unmodifiable(entries);

  final MoneyYen annualSpend;
  final List<AnnualRewardEntry> entries;

  /// 会計記録から積み上げた確定値か。false なら概算。
  final bool isExact;

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

/// 年間集計に渡す1回の支払い（D-160）。
///
/// 会計記録から作る。月間合算のルールは同じ月の取引をまとめて評価し、
/// 取引単位のルールは1件ずつ評価する。
final class AnnualSpendTransaction {
  const AnnualSpendTransaction({
    required this.date,
    required this.amount,
    this.instrumentId,
    this.merchantId,
    this.merchantGroupIds = const <StableId>[],
    this.categoryIds = const <StableId>[],
  });

  final CalculationDate date;
  final MoneyYen amount;

  /// 実際に使ったカード（D-161）。
  ///
  /// 指定すると、そのカードの還元だけを積み上げる。null のときだけ
  /// 従来どおり全カード分を合算する（カードが特定できない旧形式の記録用）。
  final StableId? instrumentId;

  final StableId? merchantId;
  final List<StableId> merchantGroupIds;
  final List<StableId> categoryIds;

  int get year => date.year;
  int get month => date.month;
}

/// 年間の還元額をカードごとに集計する（D-102・D-160）。
///
/// 取引（会計記録）が渡された場合は、カードごとに次のように積み上げる。
///
/// - 取引単位のルール: 1件ずつ端数処理する（`floor(A / U)` を毎回適用）
/// - 月間合算のルール: 同じ月の取引を合算してから端数処理する
///   （`floor(月合計 / U)`。取引ごとの増分の総和がこれに一致する）
/// - 年間到達ボーナス: 年間の合計額が閾値以上なら加算する
///
/// 取引が渡されない場合のみ、年間利用額を1回の支払いとみなした概算に
/// フォールバックする（[AnnualRewardSummary.isExact] が false）。
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
    List<AnnualSpendTransaction> transactions = const <AnnualSpendTransaction>[],
  }) {
    final context = conditionContext ?? ConditionEvaluationContext();
    final usable = <AnnualSpendTransaction>[
      for (final transaction in transactions)
        if (transaction.amount.yen > 0) transaction,
    ];

    if (usable.isNotEmpty) {
      return _fromTransactions(
        catalog: catalog,
        transactions: usable,
        conditionContext: context,
        hiddenCardIds: hiddenCardIds,
      );
    }

    return _estimate(
      catalog: catalog,
      annualSpend: annualSpend,
      transactionDate: transactionDate,
      conditionContext: context,
      hiddenCardIds: hiddenCardIds,
    );
  }

  /// 各取引の還元額（円）を、月内の累計を踏まえて求める（D-163）。
  ///
  /// [transactions] は同じ月の取引を日付順に並べたもの。返り値は同じ並びで、
  /// それぞれの取引で増えた還元額（円・切り捨て）を返す。月間合算のルールは
  /// そのカードの月内の累計から増分を出し、取引単位のルールは1件ずつ出す。
  List<int> rewardYenPerTransaction({
    required Catalog catalog,
    required List<AnnualSpendTransaction> transactions,
    ConditionEvaluationContext? conditionContext,
  }) {
    final context = conditionContext ?? ConditionEvaluationContext();
    final periodKeyInstruments = _periodKeyInstruments(catalog);
    final running = <StableId, MoneyYen>{};
    final result = <int>[];

    for (final transaction in transactions) {
      final used = transaction.instrumentId;

      final ranking = _evaluator.evaluate(
        catalog: catalog,
        amount: transaction.amount,
        transactionDate: transaction.date,
        conditionContext: context,
        merchantId: transaction.merchantId,
        merchantGroupIds: transaction.merchantGroupIds,
        categoryIds: transaction.categoryIds,
        periodSpendBeforeByKey: running,
      );

      var micros = 0;
      for (final entry in ranking.allEntries) {
        if (used != null && entry.instrumentId != used) {
          continue;
        }
        micros += entry.confirmedValue.micros;
      }
      result.add(micros ~/ 1000000);

      for (final periodEntry in periodKeyInstruments.entries) {
        final instruments = periodEntry.value;
        if (used != null &&
            instruments.isNotEmpty &&
            !instruments.contains(used)) {
          continue;
        }
        running[periodEntry.key] =
            (running[periodEntry.key] ?? MoneyYen.zero) + transaction.amount;
      }
    }

    return result;
  }

  /// 期間集計のキーと、そのキーを使うカードの対応（D-161）。
  Map<StableId, Set<StableId>> _periodKeyInstruments(Catalog catalog) {
    final result = <StableId, Set<StableId>>{};
    for (final rule in catalog.rewardRulesById.values) {
      if (rule.status == CatalogItemStatus.draft) {
        continue;
      }
      if (rule.aggregation.scope == RewardAggregationScope.transaction) {
        continue;
      }
      final key = rule.aggregation.aggregationKey;
      if (key == null) {
        continue;
      }
      result.putIfAbsent(key, () => <StableId>{}).addAll(
            rule.selectors.instrumentIds,
          );
    }

    return result;
  }

  /// 実際の取引から、カードごとに月次・取引単位を分けて積み上げる（D-160）。
  AnnualRewardSummary _fromTransactions({
    required Catalog catalog,
    required List<AnnualSpendTransaction> transactions,
    required ConditionEvaluationContext conditionContext,
    required Set<String> hiddenCardIds,
  }) {
    // 月ごとにまとめる。月が変わると期間の集計は0から始まる。
    final byMonth = <String, List<AnnualSpendTransaction>>{};
    for (final transaction in transactions) {
      final key = '${transaction.year}-'
          '${transaction.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => <AnnualSpendTransaction>[]).add(transaction);
    }

    final monthKeys = byMonth.keys.toList()..sort();
    for (final key in monthKeys) {
      byMonth[key]!.sort((left, right) => left.date.compareTo(right.date));
    }

    // 期間集計のキー（月間合算のルールが使う）と、そのキーを使うカード（D-161）。
    // カードごとに月の合計は別なので、他のカードの利用を混ぜない。
    final periodKeyInstruments = _periodKeyInstruments(catalog);

    final valueMicros = <StableId, int>{};
    final spendByInstrument = <StableId, int>{};
    final unresolved = <StableId>{};
    var totalSpendYen = 0;
    var hasInstrumentInfo = false;

    for (final monthKey in monthKeys) {
      final running = <StableId, MoneyYen>{};

      for (final transaction in byMonth[monthKey]!) {
        totalSpendYen += transaction.amount.yen;

        final used = transaction.instrumentId;
        if (used != null) {
          hasInstrumentInfo = true;
          spendByInstrument[used] =
              (spendByInstrument[used] ?? 0) + transaction.amount.yen;
        }

        final ranking = _evaluator.evaluate(
          catalog: catalog,
          amount: transaction.amount,
          transactionDate: transaction.date,
          conditionContext: conditionContext,
          merchantId: transaction.merchantId,
          merchantGroupIds: transaction.merchantGroupIds,
          categoryIds: transaction.categoryIds,
          periodSpendBeforeByKey: running,
        );

        for (final entry in ranking.allEntries) {
          // 実際に使ったカードの分だけを積み上げる（D-161）。
          // 全カードで使った想定の合計を足すと、意味のない額になるため。
          if (used != null && entry.instrumentId != used) {
            continue;
          }
          valueMicros[entry.instrumentId] =
              (valueMicros[entry.instrumentId] ?? 0) +
                  entry.confirmedValue.micros;
          if (entry.hasUnresolvedConditions) {
            unresolved.add(entry.instrumentId);
          }
        }

        for (final periodEntry in periodKeyInstruments.entries) {
          final instruments = periodEntry.value;
          if (used != null &&
              instruments.isNotEmpty &&
              !instruments.contains(used)) {
            continue;
          }
          running[periodEntry.key] =
              (running[periodEntry.key] ?? MoneyYen.zero) + transaction.amount;
        }
      }
    }

    final annualSpend = MoneyYen(totalSpendYen);

    final entries = <AnnualRewardEntry>[];
    for (final instrument in catalog.paymentInstrumentsById.values) {
      if (hiddenCardIds.contains(instrument.id.value)) {
        continue;
      }

      final base = MicrosYen(valueMicros[instrument.id] ?? 0);
      final bonus = _bonusFor(
        catalog: catalog,
        instrumentId: instrument.id,
        // 年間到達ボーナスは、そのカードで使った額で判定する（D-161）。
        // カードが特定できない旧形式の記録だけ、年間の合計額で判定する。
        annualSpend: hasInstrumentInfo
            ? MoneyYen(spendByInstrument[instrument.id] ?? 0)
            : annualSpend,
        transactionDate: transactions.last.date,
      );
      final total = base + bonus.value;

      entries.add(
        AnnualRewardEntry(
          instrumentId: instrument.id,
          instrumentName: instrument.name,
          annualFee: instrument.annualFee,
          baseValue: base,
          bonusValue: bonus.value,
          totalValue: total,
          effectiveRate: _rate(total, annualSpend),
          feeWaivedNextYear: bonus.waivesFee,
          hasUnresolvedConditions: unresolved.contains(instrument.id),
          isExact: true,
        ),
      );
    }

    return AnnualRewardSummary(
      annualSpend: annualSpend,
      entries: entries,
      isExact: true,
    );
  }

  /// 取引が無いときの概算（年間利用額を1回の支払いとみなす）。
  AnnualRewardSummary _estimate({
    required Catalog catalog,
    required MoneyYen annualSpend,
    required CalculationDate transactionDate,
    required ConditionEvaluationContext conditionContext,
    required Set<String> hiddenCardIds,
  }) {
    final ranking = _evaluator.evaluate(
      catalog: catalog,
      amount: annualSpend,
      transactionDate: transactionDate,
      conditionContext: conditionContext,
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
          isExact: false,
        ),
      );
    }

    return AnnualRewardSummary(
      annualSpend: annualSpend,
      entries: entries,
      isExact: false,
    );
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

      if (rule.tags.any((tag) => tag.value == 'annual_fee_waiver')) {
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

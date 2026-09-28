import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/annual/annual_record.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/domain/ranking/reward_ranking.dart';
import 'package:bestpay/domain/ranking/reward_ranking_evaluator.dart';

/// 会計1件の還元結果（D-122）。
final class AnnualRecordLine {
  const AnnualRecordLine({
    required this.record,
    required this.bestInstrumentName,
    required this.bestValue,
    required this.baselineValue,
  });

  final AnnualRecord record;
  final String bestInstrumentName;

  /// いちばん得なカードで支払った場合の還元額。
  final MicrosYen bestValue;

  /// 基準カード（みずほ楽天カード）で支払った場合の還元額。
  final MicrosYen baselineValue;
}

/// 店舗ごとの年間集計（D-122）。
final class AnnualStoreTotal {
  const AnnualStoreTotal({
    required this.merchantId,
    required this.merchantName,
    required this.spend,
    required this.bestValue,
    required this.count,
  });

  final String merchantId;
  final String merchantName;
  final MoneyYen spend;
  final MicrosYen bestValue;
  final int count;
}

/// 年間（1月〜12月）の集計結果（D-122）。
final class AnnualRecordSummary {
  AnnualRecordSummary({
    required this.year,
    required this.totalSpend,
    required this.totalBestValue,
    required this.totalBaselineValue,
    required Iterable<AnnualRecordLine> lines,
    required Iterable<AnnualStoreTotal> storeTotals,
  })  : lines = List<AnnualRecordLine>.unmodifiable(lines),
        storeTotals = List<AnnualStoreTotal>.unmodifiable(storeTotals);

  final int year;
  final MoneyYen totalSpend;

  /// いちばん得なカードで支払った場合の還元額の合計。
  final MicrosYen totalBestValue;

  /// 基準カードで支払った場合の還元額の合計。
  final MicrosYen totalBaselineValue;

  final List<AnnualRecordLine> lines;
  final List<AnnualStoreTotal> storeTotals;

  bool get isEmpty => lines.isEmpty;

  /// 合計の還元率。
  Rational get effectiveRate {
    if (totalSpend.yen <= 0) {
      return Rational.zero;
    }

    return Rational.create(
      totalBestValue.micros,
      totalSpend.yen * MicrosYen.microsPerYen,
    ).fold(
      onSuccess: (value) => value,
      onFailure: (_) => Rational.zero,
    );
  }

  /// 基準カードとの差（最善のカードで払ったことで増えた分）。
  MicrosYen get gainOverBaseline {
    return MicrosYen(totalBestValue.micros - totalBaselineValue.micros);
  }
}

/// 会計の記録から年間の利用額と還元額を積み上げる（D-122）。
///
/// 年は暦年（1月1日〜12月31日）で区切る。12月末で締め、1月からは
/// 自動で新しい年の集計になる。
final class AnnualRecordSummaryUseCase {
  const AnnualRecordSummaryUseCase({
    RewardRankingEvaluator evaluator = const RewardRankingEvaluator(),
  }) : _evaluator = evaluator;

  final RewardRankingEvaluator _evaluator;

  AnnualRecordSummary execute({
    required Catalog catalog,
    required MerchantDirectory directory,
    required List<AnnualRecord> records,
    required int year,
    ConditionEvaluationContext? conditionContext,
    Set<String> hiddenCardIds = const <String>{},
  }) {
    final context = conditionContext ?? ConditionEvaluationContext();
    final merchantsById = <String, MerchantEntry>{
      for (final merchant in directory.merchants)
        merchant.id.value: merchant,
    };

    final merchantIds = <StableId>[];
    final merchantGroupIds = <StableId>[];
    final categoryIds = <StableId>[];

    final lines = <AnnualRecordLine>[];
    var totalSpend = 0;
    var totalBest = 0;
    var totalBaseline = 0;
    final storeSpend = <String, int>{};
    final storeBest = <String, int>{};
    final storeCount = <String, int>{};
    final storeNames = <String, String>{};

    for (final record in records) {
      if (record.year != year) {
        continue;
      }

      final merchant = merchantsById[record.merchantId];
      merchantIds.clear();
      merchantGroupIds.clear();
      categoryIds.clear();
      if (merchant != null) {
        merchantIds.add(merchant.id);
        merchantGroupIds.addAll(merchant.groupIds);
        categoryIds.addAll(merchant.categoryIds);
      }

      final ranking = _evaluator.evaluate(
        catalog: catalog,
        amount: MoneyYen(record.amountYen),
        transactionDate: record.date,
        conditionContext: context,
        merchantId: merchantIds.isEmpty ? null : merchantIds.first,
        merchantGroupIds: merchantGroupIds,
        categoryIds: categoryIds,
      );

      final visible = <RewardRankingEntry>[
        for (final entry in ranking.allEntries)
          if (!hiddenCardIds.contains(entry.instrumentId.value)) entry,
      ];

      var best = 0;
      var bestName = '計算できません';
      for (final entry in visible) {
        if (entry.confirmedValue.micros > best ||
            bestName == '計算できません') {
          best = entry.confirmedValue.micros;
          bestName = entry.instrumentName;
        }
      }

      final baseline = ranking.baselineEntry;
      final baselineValue = baseline != null &&
              !hiddenCardIds.contains(baseline.instrumentId.value)
          ? baseline.confirmedValue.micros
          : 0;

      totalSpend += record.amountYen;
      totalBest += best;
      totalBaseline += baselineValue;

      storeSpend.update(
        record.merchantId,
        (value) => value + record.amountYen,
        ifAbsent: () => record.amountYen,
      );
      storeBest.update(
        record.merchantId,
        (value) => value + best,
        ifAbsent: () => best,
      );
      storeCount.update(
        record.merchantId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      storeNames[record.merchantId] = record.merchantName;

      lines.add(
        AnnualRecordLine(
          record: record,
          bestInstrumentName: bestName,
          bestValue: MicrosYen(best),
          baselineValue: MicrosYen(baselineValue),
        ),
      );
    }

    final storeTotals = <AnnualStoreTotal>[];
    for (final entry in storeSpend.entries) {
      storeTotals.add(
        AnnualStoreTotal(
          merchantId: entry.key,
          merchantName: storeNames[entry.key] ?? entry.key,
          spend: MoneyYen(entry.value),
          bestValue: MicrosYen(storeBest[entry.key] ?? 0),
          count: storeCount[entry.key] ?? 0,
        ),
      );
    }
    storeTotals.sort(
      (left, right) => right.spend.yen.compareTo(left.spend.yen),
    );

    return AnnualRecordSummary(
      year: year,
      totalSpend: MoneyYen(totalSpend),
      totalBestValue: MicrosYen(totalBest),
      totalBaselineValue: MicrosYen(totalBaseline),
      lines: lines,
      storeTotals: storeTotals,
    );
  }
}

/// 記録の日付から暦年を取り出す。
int yearOf(CalculationDate date) => date.year;

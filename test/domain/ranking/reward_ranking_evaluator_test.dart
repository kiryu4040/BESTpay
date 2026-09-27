import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/ranking/reward_ranking.dart';
import 'package:bestpay/domain/ranking/reward_ranking_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/sample_catalog_fixture.dart';

void main() {
  final catalog = loadSampleCatalog();
  final transactionDate = _date('2026-09-27');

  const evaluator = RewardRankingEvaluator();

  RewardRankingEntry entryFor(RewardRanking ranking, String instrumentId) {
    return ranking.confirmed.firstWhere(
      (entry) => entry.instrumentId.value == instrumentId,
    );
  }

  group('端数処理', () {
    test('150円につき1pt で 200円は1pt', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: const MoneyYen(200),
        transactionDate: transactionDate,
      );

      final entry = entryFor(ranking, 'sample_card_a');
      expect(entry.totalPoints.points, 1);
      expect(entry.confirmedValue.micros, MicrosYen.microsPerYen);
    });

    test('単位未満は0pt、301円は2pt', () {
      final under = evaluator.evaluate(
        catalog: catalog,
        amount: const MoneyYen(149),
        transactionDate: transactionDate,
      );
      expect(entryFor(under, 'sample_card_a').totalPoints.points, 0);

      final over = evaluator.evaluate(
        catalog: catalog,
        amount: const MoneyYen(301),
        transactionDate: transactionDate,
      );
      expect(entryFor(over, 'sample_card_a').totalPoints.points, 2);
    });
  });

  group('ランキング順序', () {
    test('確定した円換算価値の降順に並ぶ', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: const MoneyYen(10000),
        transactionDate: transactionDate,
      );

      expect(
        ranking.confirmed.map((entry) => entry.instrumentId.value).toList(),
        <String>['sample_card_b', 'sample_card_a', 'sample_card_c'],
      );
      expect(
        ranking.confirmed.first.confirmedValue.micros,
        100 * MicrosYen.microsPerYen,
      );
    });

    test('同順位は instrumentId の辞書順で決まる (D-42)', () {
      final entries = <RewardRankingEntry>[
        _entry('sample_card_z', yen: 100),
        _entry('sample_card_a', yen: 100),
      ]..sort(compareRankingEntries);

      expect(
        entries.map((entry) => entry.instrumentId.value).toList(),
        <String>['sample_card_a', 'sample_card_z'],
      );
    });

    test('同順位は年会費より手順数を優先する (D-42)', () {
      final entries = <RewardRankingEntry>[
        _entry('sample_card_a', yen: 100, stepCount: 2, annualFee: 0),
        _entry('sample_card_b', yen: 100, stepCount: 1, annualFee: 5000),
      ]..sort(compareRankingEntries);

      expect(entries.first.instrumentId.value, 'sample_card_b');
    });
  });

  group('基準カードとの比較と期間入力の撤廃 (D-084, D-085)', () {
    test('既定の基準はみずほ楽天カードで、カタログに無ければ基準行は null', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: const MoneyYen(10000),
        transactionDate: transactionDate,
      );

      expect(ranking.baselineInstrumentId!.value, 'mizuho_rakuten_card');
      expect(ranking.baselineEntry, isNull);
      expect(ranking.betterThanBaseline, isEmpty);
      expect(ranking.bestEntry, isNotNull);
    });

    test('基準カードを指定すると、それを上回るカードだけが抽出される', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: const MoneyYen(10000),
        transactionDate: transactionDate,
        baselineCardId: _sid('sample_card_a'),
      );

      final baseline = ranking.baselineEntry!;
      expect(baseline.isBaseline, isTrue);
      expect(baseline.beatsBaseline, isFalse);

      for (final entry in ranking.allEntries) {
        if (entry.isBaseline) {
          continue;
        }

        expect(
          entry.beatsBaseline,
          entry.confirmedValue.micros > baseline.confirmedValue.micros,
          reason: entry.instrumentId.value,
        );
      }

      for (final entry in ranking.betterThanBaseline) {
        expect(
          entry.confirmedValue.micros > baseline.confirmedValue.micros,
          isTrue,
        );
      }
    });

    test('期間集計ルールも期間入力をとらず、単一取引として確定評価される', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: const MoneyYen(200),
        transactionDate: transactionDate,
      );

      // 月間・年間の集計額は入力しない（D-085）。すべて確定として扱われる。
      expect(ranking.estimated, isEmpty);
      expect(
        ranking.allEntries.every((entry) => entry.confidence.label == '確定'),
        isTrue,
      );
    });
  });


}

RewardRankingEntry _entry(
  String instrumentId, {
  required int yen,
  int stepCount = 1,
  int annualFee = 0,
}) {
  return RewardRankingEntry(
    instrumentId: _sid(instrumentId),
    instrumentName: instrumentId,
    programAwards: const <ProgramPointAward>[],
    totalPoints: PointAmount(yen),
    confirmedValue: MicrosYen(yen * MicrosYen.microsPerYen),
    effectiveRate: Rational.zero,
    confidence: RewardConfidence.confirmed,
    stepCount: stepCount,
    annualFee: MoneyYen(annualFee),
    hasUnconvertiblePoints: false,
    hasUnresolvedConditions: false,
  );
}

StableId _sid(String value) {
  return StableId.create(value).fold(
    onSuccess: (id) => id,
    onFailure: (_) => throw StateError('不正なID: $value'),
  );
}

CalculationDate _date(String value) {
  return CalculationDate.parse(value).fold(
    onSuccess: (date) => date,
    onFailure: (_) => throw StateError('不正な日付: $value'),
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_evaluation_input.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_evaluation_result.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_evaluator.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_validator.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:bestpay/domain/ranking/period_increment_calculator.dart';
import 'package:bestpay/domain/ranking/reward_ranking.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/domain/ranking/reward_ranking_evaluator.dart';
import 'package:bestpay/infrastructure/catalog/json_catalog_decoder.dart';
import 'package:bestpay/infrastructure/merchant/merchant_directory_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

StableId id(String value) {
  return StableId.create(value).fold(
    onSuccess: (decoded) => decoded,
    onFailure: (_) => throw StateError('invalid stable id: $value'),
  );
}

CalculationDate date(String value) {
  return CalculationDate.parse(value).fold(
    onSuccess: (decoded) => decoded,
    onFailure: (_) => throw StateError('invalid date: $value'),
  );
}

MoneyYen yen(int value) => MoneyYen(value);

Map<String, Object?> readCatalogDocument(String fileName) {
  final decoded = json.decode(
    File('assets/data/$fileName').readAsStringSync(),
  );

  return (decoded as Map<dynamic, dynamic>).cast<String, Object?>();
}

/// assets/data/ の実カタログ（ダミーではなく実在カード6枚）を読み込む。
Catalog loadRealCatalog() {
  return const JsonCatalogDecoder().decode(
    manifest: readCatalogDocument('catalog_manifest.json'),
    paymentInstruments: readCatalogDocument('payment_instruments.json'),
    pointPrograms: readCatalogDocument('point_programs.json'),
    rewardRules: readCatalogDocument('reward_rules.json'),
    sources: readCatalogDocument('sources.json'),
  );
}

/// 実データの店舗一覧（assets/data/merchants.json）を読み込む。
MerchantDirectory loadRealDirectory() {
  return const MerchantDirectoryDecoder().decode(
    merchants: readCatalogDocument('merchants.json'),
    merchantCategories: readCatalogDocument('merchant_categories.json'),
  );
}

/// 実カード6枚のカタログ（assets/data/）を使ったゴールデンテスト。
///
/// 期待値は research/card_research.md とカード各社の公式ページ（2026-09-27確認）
/// から導出する。公式に未確認の項目はカタログ側で notes に明記し、
/// ここでは仮定した値のみを固定する。
void main() {
  final catalog = loadRealCatalog();
  final directory = loadRealDirectory();

  const evaluator = RewardRankingEvaluator();

  final transactionDate = date('2026-09-27');

  RewardRankingEntry entryFor(RewardRanking ranking, String instrumentId) {
    for (final entry in <RewardRankingEntry>[
      ...ranking.confirmed,
      ...ranking.estimated,
    ]) {
      if (entry.instrumentId.value == instrumentId) {
        return entry;
      }
    }

    throw StateError('entry not found: $instrumentId');
  }


  ConditionEvaluationContext satisfiedContext() {
    return ConditionEvaluationContext(
      states: <StableId, TriState>{
        id('mizuho_w_point_plan_eligible'): TriState.satisfied,
      },
    );
  }

  int pointsFor(String cardId, int amountYen) {
    final ranking = evaluator.evaluate(
      catalog: catalog,
      amount: yen(amountYen),
      transactionDate: transactionDate,
    );

    return entryFor(ranking, cardId).totalPoints.points;
  }

  RewardRuleSetEvaluationResult evaluateRuleSet(
    List<RewardRule> rules,
    RewardEvaluationInput input,
  ) {
    final result = const RewardRuleSetEvaluator().evaluateResult(
      rules: rules,
      input: input,
    );

    return result.fold<RewardRuleSetEvaluationResult>(
      onSuccess: (value) => value,
      onFailure: (error) => fail('ルール評価に失敗した: $error'),
    );
  }

  RewardEvaluationInput vNeobankInput({
    required int amountYen,
    required String settlementDataReceivedDate,
  }) {
    return RewardEvaluationInput(
      amount: yen(amountYen),
      instrumentId: id('v_neobank_debit'),
      modeId: null,
      routeId: null,
      merchantId: null,
      settlementDataReceivedDate: date(settlementDataReceivedDate),
      conditionContext: ConditionEvaluationContext(),
    );
  }

  group('カタログのデコード', () {
    test('実カード6枚がデコードでき、Catalogが構築できる', () {
      expect(catalog.isNotEmpty, isTrue);
      expect(catalog.catalogVersion, '2026.10.02.3');
      expect(catalog.generatedAt, '2026-10-02T00:00:00+09:00');

      expect(
        catalog.paymentInstrumentsById.keys.map((key) => key.value).toList()
          ..sort(),
        <String>[
          'aeon_card',
          'd_card',
          'jcb_card_w',
          'mizuho_rakuten_card',
          'mufg_card',
          'olive_flexible_pay_gold',
          'paypay_card',
          'smbc_gold_nl_card',
          'v_neobank_debit',
          'welcia_card',
        ],
      );

      expect(
        catalog.pointProgramsById.keys.map((key) => key.value).toList()..sort(),
        <String>[
          'd_point',
          'global_point',
          'j_point',
          'mizuho_point',
          'paypay_point',
          'rakuten_point',
          'v_point',
          'waon_point',
        ],
      );

      // 有効期間を過ぎたルール（iD特約店終了の4件）は読み込み時に除かれる（D-152）。
      // ディスク上は117件、読み込み後は113件。
      expect(catalog.rewardRulesById.length, 113);
      expect(catalog.sourcesById.length, 57);

      final mizuho = catalog.paymentInstrumentsById[id('mizuho_rakuten_card')]!;
      expect(mizuho.instrumentType, 'creditCard');
      expect(mizuho.annualFee.yen, 0);
      expect(mizuho.status.value, 'active');

      final neobank = catalog.paymentInstrumentsById[id('v_neobank_debit')]!;
      expect(neobank.instrumentType, 'debitCard');
      expect(neobank.issuerName, '株式会社ドコモSMTBネット銀行');
    });

    test('全ルールがバリデータを通過し、cap はすべて null', () {
      expect(catalog.rewardRulesById, isNotEmpty);

      final validation = const RewardRuleSetValidator().validateAndOrder(
        catalog.rewardRulesById.values,
      );
      final isValid = validation.fold<bool>(
        onSuccess: (_) => true,
        onFailure: (_) => false,
      );
      expect(isValid, isTrue, reason: 'ルールセットがバリデータを通過すること');

      final active = catalog.rewardRulesById.values
          .where((rule) => rule.status.value == 'active')
          .toList();
      final draft = catalog.rewardRulesById.values
          .where((rule) => rule.status.value == 'draft')
          .toList();

      // 有効期間外を除いたactiveは107件（D-152）。
      expect(active.length, 107);
      expect(draft.length, 6);

      for (final rule in catalog.rewardRulesById.values) {
        expect(rule.cap, isNull, reason: rule.id.value);
        expect(
          rule.aggregation.conditionEvaluationTiming,
          'transaction',
          reason: rule.id.value,
        );

        if (rule.aggregation.scope.value == 'transaction') {
          expect(rule.aggregation.aggregationKey, isNull, reason: rule.id.value);
          expect(
            rule.aggregation.incrementalAward,
            isFalse,
            reason: rule.id.value,
          );
        } else {
          expect(
            rule.aggregation.aggregationKey,
            isNotNull,
            reason: rule.id.value,
          );
          expect(
            rule.aggregation.incrementalAward,
            isTrue,
            reason: rule.id.value,
          );
        }
      }
    });

    test('参照整合性: sourceIds / outputPointProgramId / instrumentIds が実在する', () {
      for (final rule in catalog.rewardRulesById.values) {
        expect(rule.sourceIds, isNotEmpty, reason: rule.id.value);
        for (final sourceId in rule.sourceIds) {
          expect(
            catalog.sourcesById.containsKey(sourceId),
            isTrue,
            reason: '${rule.id.value} -> ${sourceId.value}',
          );
        }

        final programId = rule.outputPointProgramId;
        expect(programId, isNotNull, reason: rule.id.value);
        expect(
          catalog.pointProgramsById.containsKey(programId!),
          isTrue,
          reason: '${rule.id.value} -> ${programId.value}',
        );

        expect(rule.selectors.instrumentIds, isNotEmpty, reason: rule.id.value);
        for (final instrumentId in rule.selectors.instrumentIds) {
          expect(
            catalog.paymentInstrumentsById.containsKey(instrumentId),
            isTrue,
            reason: '${rule.id.value} -> ${instrumentId.value}',
          );
        }
      }

      for (final instrument in catalog.paymentInstrumentsById.values) {
        expect(instrument.sourceIds, isNotEmpty, reason: instrument.id.value);
        for (final sourceId in instrument.sourceIds) {
          expect(
            catalog.sourcesById.containsKey(sourceId),
            isTrue,
            reason: '${instrument.id.value} -> ${sourceId.value}',
          );
        }
      }

      for (final program in catalog.pointProgramsById.values) {
        expect(program.sourceIds, isNotEmpty, reason: program.id.value);
        for (final sourceId in program.sourceIds) {
          expect(
            catalog.sourcesById.containsKey(sourceId),
            isTrue,
            reason: '${program.id.value} -> ${sourceId.value}',
          );
        }
      }
    });

    test('条件定義はカタログに置き、達成状態は保持しない', () {
      final document = readCatalogDocument('condition_definitions.json');
      final items = (document['items']! as List).cast<Map<String, dynamic>>();
      final condition = items.singleWhere(
        (item) => item['id'] == 'mizuho_w_point_plan_eligible',
      );

      expect(condition['valueType'], 'boolean');
      expect(condition['defaultState'], 'satisfied');
      expect(condition['verificationMethod'], 'userInput');
      expect(condition['status'], 'active');

      // 達成状態はカタログに保存しない（アプリの条件設定画面で入力する）。
      expect(condition.containsKey('state'), isFalse);
      expect(condition.containsKey('achieved'), isFalse);
    });
  });

  group('みずほ楽天カード: 取引ごとの計算（訂正1）', () {
    test('集計範囲は transaction で、月間合算ではない', () {
      final rule =
          catalog.rewardRulesById[id('mizuho_rakuten_base_rakuten_point')]!;

      expect(rule.aggregation.scope.value, 'transaction');
      expect(rule.aggregation.aggregationKey, isNull);
      expect(rule.aggregation.incrementalAward, isFalse);
    });

    test('150円→1pt（1取引ごとに100円未満切捨て）', () {
      expect(pointsFor('mizuho_rakuten_card', 150), 1);
      expect(pointsFor('mizuho_rakuten_card', 100), 1);
      expect(pointsFor('mizuho_rakuten_card', 99), 0);
      expect(pointsFor('mizuho_rakuten_card', 250), 2);
    });

    test('月間合算していない: 99円の取引は何度でも0pt', () {
      expect(pointsFor('mizuho_rakuten_card', 99), 0);
      expect(pointsFor('mizuho_rakuten_card', 99), 0);
      // 月間合算なら 99+99=198円 → 1pt になるが、取引ごとの計算なので 0pt。
      expect(pointsFor('mizuho_rakuten_card', 10), 0);
    });

    test('カテゴリ別の draft ルールは計算に反映されない', () {
      final draft = catalog.rewardRulesById.values
          .where((rule) => rule.status.value == 'draft')
          .map((rule) => rule.id.value)
          .toList()
        ..sort();

      expect(draft..sort(), <String>[
        'jcb_card_w_point_up_go_taxi',
        'jcb_card_w_point_up_s_ride',
        'jcb_card_w_point_up_uber',
        'mizuho_rakuten_insurance_draft',
        'mizuho_rakuten_mobile_draft',
        'mizuho_rakuten_utility_draft',
      ]);

      // 通常ルールのみが適用される（draft の 500円1pt が混ざれば 10000円で120ptになる）。
      expect(pointsFor('mizuho_rakuten_card', 10000), 100);
    });
  });

  group('端数処理', () {
    test('三井住友カード ゴールド（NL）: 200円で1pt、199円は0pt', () {
      expect(pointsFor('smbc_gold_nl_card', 200), 1);
      expect(pointsFor('smbc_gold_nl_card', 199), 0);
    });

    test('三菱UFJカード: 1,000円で1pt、999円は0pt（1,000円未満切捨て）', () {
      expect(pointsFor('mufg_card', 1000), 1);
      expect(pointsFor('mufg_card', 999), 0);
    });

    test('JCBカードW: 200円につき2pt', () {
      expect(pointsFor('jcb_card_w', 200), 2);
      expect(pointsFor('jcb_card_w', 400), 4);
      expect(pointsFor('jcb_card_w', 399), 3);

      // JCBの端数処理は「毎月のご利用額を合計してからポイント換算し、
      // 小数点以下は切り捨て」（JCB「J-POINTの仕組み」）。比例計算
      // （199 x 2 / 200 = 1.99 → 切捨て）では 199円は1ptとなる。
      // 「199円→0pt」となるのは200円単位で先に切り捨てるブロック計算で、
      // 本エンジンの unitPoints は比例計算のため採用していない。
      expect(pointsFor('jcb_card_w', 199), 1);
    });

    test('V NEOBANKデビット: 1.5%（3/200）で 10,000円は150pt、66円は0pt', () {
      final tenThousand = evaluateRuleSet(
        catalog.rulesApplicableToInstrument(id('v_neobank_debit')),
        vNeobankInput(
          amountYen: 10000,
          settlementDataReceivedDate: '2026-09-30',
        ),
      );
      expect(tenThousand.pointsByProgram[id('v_point')]!.points, 150);

      final small = evaluateRuleSet(
        catalog.rulesApplicableToInstrument(id('v_neobank_debit')),
        vNeobankInput(
          amountYen: 66,
          settlementDataReceivedDate: '2026-09-30',
        ),
      );
      expect(small.pointsByProgram[id('v_point')]!.points, 0);
    });
  });

  group('Oliveゴールド: 支払いモードと還元率（訂正3）', () {
    test('クレジット／デビット／ポイント払いのどのモードでも0.5%が適用される', () {
      final base =
          catalog.rewardRulesById[id('olive_flexible_pay_gold_base')]!;

      // モードを限定しない単一ルールとして登録している（第1期は
      // payment_modes.json を登録しないため、モード別の分岐はできない）。
      expect(base.selectors.modeIds, isEmpty);

      final calculation = base.calculation;
      expect(calculation, isA<RateFractionRewardCalculation>());
      expect((calculation as RateFractionRewardCalculation).rate.numerator, 1);
      expect(calculation.rate.denominator, 200);

      // モードIDはテストローカルの識別子（カタログには支払いモードを登録して
      // いない）。ルールがモードを限定しないため、どのモードIDでも同じ0.5%
      // （10,000円で50pt）になることを確認する。
      for (final mode in <String>[
        'olive_mode_credit',
        'olive_mode_debit',
        'olive_mode_point_pay',
      ]) {
        final result = evaluateRuleSet(
          <RewardRule>[base],
          RewardEvaluationInput(
            amount: yen(10000),
            instrumentId: id('olive_flexible_pay_gold'),
            modeId: id(mode),
            routeId: null,
            merchantId: null,
            transactionDate: transactionDate,
            conditionContext: ConditionEvaluationContext(),
          ),
        );

        expect(
          result.pointsByProgram[id('v_point')]!.points,
          50,
          reason: '$mode は0.5%',
        );
      }
    });

    test('二次情報の0.25%は採用していない', () {
      final base =
          catalog.rewardRulesById[id('olive_flexible_pay_gold_base')]!;

      expect(base.notes.join(' ').contains('0.25'), isTrue);
      expect(
        catalog.paymentInstrumentsById[id('olive_flexible_pay_gold')]!
            .notes
            .join(' ')
            .contains('0.25'),
        isTrue,
      );
    });
  });

  group('期間集計カードの取引単独評価（D-085・D-087）', () {
    test('三菱UFJカード: 期間0円から200円の取引で 1pt 増える（増分計算）', () {
      final rule = catalog.rewardRulesById[id('mufg_card_base_global_point')]!;
      final increment = const PeriodIncrementCalculator().compute(
        calculation: rule.calculation,
        periodSpendBefore: yen(900),
        amount: yen(200),
      );
      final value = increment.fold(
        onSuccess: (decoded) => decoded,
        onFailure: (error) => fail('増分計算に失敗した: $error'),
      );

      expect(value.pointsBefore.points, 0);
      expect(value.pointsAfter.points, 1);
      expect(value.increment.points, 1);
    });

    test('月間の集計額を入力しなくても三菱UFJカードは1,000円につき1ptで確定する', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(10000),
        transactionDate: transactionDate,
      );
      final entry = entryFor(ranking, 'mufg_card');

      expect(entry.totalPoints.points, 10);
      expect(entry.confidence, RewardConfidence.confirmed);
    });

    test('JCBカードW: 200円につき2pt（月合計の入力は不要）', () {
      expect(pointsFor('jcb_card_w', 200), 2);
      expect(pointsFor('jcb_card_w', 400), 4);
    });
  });


  group('V NEOBANKデビットの境界日（売上確定データ到着日基準）', () {
    test('2026-10-31到着は1.5%（150pt）', () {
      final result = evaluateRuleSet(
        catalog.rulesApplicableToInstrument(id('v_neobank_debit')),
        vNeobankInput(
          amountYen: 10000,
          settlementDataReceivedDate: '2026-10-31',
        ),
      );

      expect(result.pointsByProgram[id('v_point')]!.points, 150);
    });


  });

  group('みずほ楽天カードの条件付きWポイント', () {
    test('条件未入力なら みずほポイント分は確定値に加算されない', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(10000),
        transactionDate: transactionDate,
      );

      final entry = entryFor(ranking, 'mizuho_rakuten_card');

      expect(entry.totalPoints.points, 100);
      expect(
        entry.programAwards.map((award) => award.programId.value).toList(),
        <String>['rakuten_point'],
      );
      expect(
        entry.programAwards.single.convertedValue!.micros,
        100 * MicrosYen.microsPerYen,
      );
      expect(entry.hasUnresolvedConditions, isTrue);
    });

    test('条件を満たすと みずほポイントが楽天ポイントと同数加算される', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(10000),
        transactionDate: transactionDate,
        conditionContext: ConditionEvaluationContext(
          states: <StableId, TriState>{
            id('mizuho_w_point_plan_eligible'): TriState.satisfied,
          },
        ),
      );

      final entry = entryFor(ranking, 'mizuho_rakuten_card');

      expect(
        entry.programAwards.map((award) => award.programId.value).toList(),
        <String>['mizuho_point', 'rakuten_point'],
      );
      expect(entry.totalPoints.points, 200);
      expect(entry.confirmedValue.micros, 200 * MicrosYen.microsPerYen);

      final rakuten = entry.programAwards
          .firstWhere((award) => award.programId.value == 'rakuten_point');
      final mizuho = entry.programAwards
          .firstWhere((award) => award.programId.value == 'mizuho_point');
      expect(mizuho.points.points, rakuten.points.points);
    });
  });

  group('基準カード（みずほ楽天カード）との比較', () {
    test('月間・年間の集計額を使わず、全カードが確定値で比較される', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(10000),
        transactionDate: transactionDate,
      );

      expect(ranking.estimated, isEmpty);
      expect(ranking.confirmed.length, 10);

      for (var index = 1; index < ranking.confirmed.length; index++) {
        expect(
          ranking.confirmed[index - 1]
                  .confirmedValue
                  .compareTo(ranking.confirmed[index].confirmedValue) >=
              0,
          isTrue,
          reason: '確定値が降順であること',
        );
      }

      expect(entryFor(ranking, 'v_neobank_debit').totalPoints.points, 150);
      expect(entryFor(ranking, 'jcb_card_w').totalPoints.points, 100);
      expect(entryFor(ranking, 'olive_flexible_pay_gold').totalPoints.points, 50);
      expect(entryFor(ranking, 'smbc_gold_nl_card').totalPoints.points, 50);
      expect(entryFor(ranking, 'mufg_card').totalPoints.points, 10);
    });

    test('Wポイント対象者なら基準は2%で、それを上回るカードはない', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(10000),
        transactionDate: transactionDate,
        conditionContext: satisfiedContext(),
      );
      final baseline = ranking.baselineEntry!;

      expect(baseline.instrumentId.value, 'mizuho_rakuten_card');
      expect(baseline.isBaseline, isTrue);
      expect(baseline.totalPoints.points, 200);
      expect(baseline.confirmedValue.micros, 200 * MicrosYen.microsPerYen);
      expect(
        baseline.effectiveRate.numerator * 10000 ~/ baseline.effectiveRate.denominator,
        200,
        reason: '基準の還元率が2.00%であること',
      );

      expect(ranking.betterThanBaseline, isEmpty);
      expect(ranking.baselineRemainsBest, isTrue);
      expect(ranking.bestEntry!.instrumentId.value, 'mizuho_rakuten_card');
    });

    test('Wポイント未入力なら基準は1%で、上回るカードだけが示される', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(10000),
        transactionDate: transactionDate,
      );
      final baseline = ranking.baselineEntry!;

      expect(baseline.totalPoints.points, 100);
      expect(
        ranking.betterThanBaseline
            .map((entry) => entry.instrumentId.value)
            .toList(),
        <String>['v_neobank_debit'],
      );
      expect(ranking.bestEntry!.instrumentId.value, 'v_neobank_debit');
      expect(ranking.baselineRemainsBest, isFalse);
      expect(
        ranking.betterThanBaseline.single.baselineDeltaMicros,
        50 * MicrosYen.microsPerYen,
      );

      // 同額のカードは「上回る」に含めない（厳密に大きい場合だけ）。
      expect(entryFor(ranking, 'jcb_card_w').beatsBaseline, isFalse);
      expect(entryFor(ranking, 'jcb_card_w').baselineDeltaMicros, 0);
      expect(entryFor(ranking, 'olive_flexible_pay_gold').beatsBaseline, isFalse);
      expect(entryFor(ranking, 'mufg_card').beatsBaseline, isFalse);
    });

    test('基準が2%にならない支払いでも、同じ基準で比較する', () {
      // 150円は100円未満切捨てで楽天1pt＋みずほ1pt＝2円（基準 1.33%）。
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(150),
        transactionDate: transactionDate,
        conditionContext: satisfiedContext(),
      );
      final baseline = ranking.baselineEntry!;

      expect(baseline.totalPoints.points, 2);
      expect(baseline.confirmedValue.micros, 2 * MicrosYen.microsPerYen);
      expect(ranking.betterThanBaseline, isEmpty);
    });
  });

  group('ポイント種別の優先順位（D-127）', () {
    test('Vポイント＞みずほポイント＞楽天ポイント＞その他の順に並ぶ', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(10000),
        transactionDate: transactionDate,
        conditionContext: satisfiedContext(),
      );

      int priorityOf(String cardId) =>
          bestPointProgramPriority(entryFor(ranking, cardId));

      expect(priorityOf('olive_flexible_pay_gold'), 1);
      expect(priorityOf('smbc_gold_nl_card'), 1);
      expect(priorityOf('mizuho_rakuten_card'), 2);
      expect(priorityOf('mufg_card'), 4);

      expect(
        priorityOf('olive_flexible_pay_gold') <
            priorityOf('mizuho_rakuten_card'),
        isTrue,
        reason: 'Vポイントのほうが優先される',
      );
    });

    test('同額なら優先度の高いポイントのカードが上位になる', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(10000),
        transactionDate: transactionDate,
        conditionContext: satisfiedContext(),
      );

      // 三菱UFJカード（10pt・グローバルポイント）と
      // みずほ楽天カード（200pt・みずほ＋楽天）は額が違うため、
      // 額の大きいほうが先になる（ポイント優先より額が先）。
      expect(
        entryFor(ranking, 'mizuho_rakuten_card').totalPoints.points >
            entryFor(ranking, 'mufg_card').totalPoints.points,
        isTrue,
      );

      final baseline = ranking.baselineEntry!;
      final olive = entryFor(ranking, 'olive_flexible_pay_gold');
      expect(
        olive.confirmedValue.compareTo(baseline.confirmedValue) < 0,
        isTrue,
        reason: 'Oliveは基本還元のみでは基準（2%）を下回るので順位は下',
      );
    });
  });

  group('店舗を選ぶだけの比較（D-088〜D-090）', () {
    MerchantEntry merchant(String idValue) {
      return directory.merchants.firstWhere(
        (item) => item.id.value == idValue,
      );
    }

    /// 上乗せ特典のないカテゴリ（ネット通販）の店舗。基本還元だけの比較に使う。
    MerchantEntry noBonusMerchant() {
      return directory.merchants.firstWhere(
        (item) => item.categoryIds.any(
          (category) => category.value == 'online_shop',
        ),
      );
    }

    RewardRanking compareAt(String merchantId, {bool satisfied = true}) {
      final target = merchant(merchantId);

      return evaluator.evaluate(
        catalog: catalog,
        amount: yen(10000),
        transactionDate: transactionDate,
        merchantId: target.id,
        merchantGroupIds: target.groupIds,
        categoryIds: target.categoryIds,
        conditionContext: satisfied ? satisfiedContext() : null,
      );
    }

    test('店舗一覧が16件読み込め、得意店舗なしの受け皿は登録しない', () {
      expect(directory.merchants.length, 109);
      expect(
        directory.merchants.any((m) => m.id.value == 'other_merchant'),
        isFalse,
      );
      expect(directory.categoriesById.containsKey(id('other_store')), isFalse);
      expect(directory.categoriesById.length, 17);
      expect(directory.search('セブン').single.name, 'セブン-イレブン');
    });

    test('ひらがな・カタカナ・半角カナ・略称でも絞り込める（D-140）', () {
      expect(directory.search('スタバ').single.name, 'スターバックス');
      expect(directory.search('すたば').single.name, 'スターバックス');
      expect(directory.search('ｽﾀﾊﾞ').single.name, 'スターバックス');
      expect(directory.search('スターバ').single.name, 'スターバックス');
      expect(directory.search('ファミマ').single.name, 'ファミリーマート');
      expect(directory.search('まつや').single.name, '松屋');
      expect(directory.search('よしのや').single.name, '吉野家');
      expect(directory.search('マクド').single.name, 'マクドナルド');
      expect(
        directory.search('マック').map((m) => m.id.value),
        containsAll(<String>['maxvalu', 'mcdonalds']),
      );
      expect(directory.search('にくのはなまさ').single.name, '肉のハナマサ');
      expect(directory.search('ドミノピザ').single.name, 'ドミノ・ピザ');
      expect(directory.search('Ａｍａｚｏｎ').single.name, 'Amazon.co.jp');
      expect(directory.search('らくてん').map((m) => m.id.value), contains('rakuten_market'));
      expect(directory.search('・').length, directory.merchants.length);
      expect(directory.search('存在しない店').isEmpty, isTrue);
    });

    test('セブン-イレブンではOliveゴールドが8%で最上位になる', () {
      final ranking = compareAt('seven_eleven');

      expect(entryFor(ranking, 'olive_flexible_pay_gold').totalPoints.points, 800);
      expect(entryFor(ranking, 'smbc_gold_nl_card').totalPoints.points, 700);
      expect(entryFor(ranking, 'mufg_card').totalPoints.points, 140);
      expect(
        entryFor(ranking, 'mufg_card').confirmedValue.micros,
        700 * MicrosYen.microsPerYen,
        reason: '1ポイント5円相当なので140pt＝700円（7%）になること',
      );
      expect(
        entryFor(ranking, 'mizuho_rakuten_card').totalPoints.points,
        200,
        reason: '基準（みずほ楽天カード・Wポイント対象者）は2%',
      );
      expect(ranking.bestEntry!.instrumentId.value, 'olive_flexible_pay_gold');
      // 同額（700円）の三菱UFJカードとSMBCゴールドNLは、受け取れるポイントの
      // 優先順位で並ぶ。VポイントのSMBCが先、グローバルポイントの三菱UFJが後（D-127）。
      expect(
        ranking.betterThanBaseline
            .map((entry) => entry.instrumentId.value)
            .toList(),
        <String>['olive_flexible_pay_gold', 'smbc_gold_nl_card', 'mufg_card'],
      );
      expect(
        entryFor(ranking, 'mufg_card').confirmedValue.micros,
        entryFor(ranking, 'smbc_gold_nl_card').confirmedValue.micros,
        reason: '還元額（円）が同じ700円であること。点数の単位が違うため'
            '比較するのは円換算後の値',
      );
    });

    test('マクドナルドではOliveゴールドが8%で最上位、SMBCは7%になる', () {
      final ranking = compareAt('mcdonalds');

      expect(entryFor(ranking, 'smbc_gold_nl_card').totalPoints.points, 700);
      expect(entryFor(ranking, 'olive_flexible_pay_gold').totalPoints.points, 800);
      expect(
        ranking.bestEntry!.instrumentId.value,
        'olive_flexible_pay_gold',
      );
    });

    test('上乗せのない店（Amazon.co.jp）では基本還元だけで比較し、基準のままになる', () {
      final ranking = compareAt(noBonusMerchant().id.value);

      expect(entryFor(ranking, 'olive_flexible_pay_gold').totalPoints.points, 50);
      expect(entryFor(ranking, 'smbc_gold_nl_card').totalPoints.points, 50);
      expect(entryFor(ranking, 'mufg_card').totalPoints.points, 10);
      expect(ranking.baselineRemainsBest, isTrue);
      expect(ranking.bestEntry!.instrumentId.value, 'mizuho_rakuten_card');
    });

    test('Wポイント未入力なら基準が1%になり、上乗せのない店でも基準超えが出る', () {
      final ranking = compareAt(noBonusMerchant().id.value, satisfied: false);

      expect(
        entryFor(ranking, 'mizuho_rakuten_card').totalPoints.points,
        100,
      );
      expect(
        ranking.betterThanBaseline
            .map((entry) => entry.instrumentId.value)
            .toList(),
        <String>['v_neobank_debit'],
      );
    });

    test('店舗を指定しなければ店舗上乗せは効かない', () {
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(10000),
        transactionDate: transactionDate,
        conditionContext: satisfiedContext(),
      );

      expect(entryFor(ranking, 'olive_flexible_pay_gold').totalPoints.points, 50);
      expect(entryFor(ranking, 'smbc_gold_nl_card').totalPoints.points, 50);
      expect(entryFor(ranking, 'mufg_card').totalPoints.points, 10);
    });

    test('楽天市場はみずほ楽天カードで楽天ポイント3%になる（D-134）', () {
      final shop = merchant('rakuten_market');
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(10000),
        transactionDate: date('2026-09-29'),
        merchantId: shop.id,
        merchantGroupIds: shop.groupIds,
        categoryIds: shop.categoryIds,
        conditionContext: satisfiedContext(),
      );

      // 楽天ポイントは基本1%（100pt）＋楽天市場分2%（200pt）＝300pt（3%）。
      final rakuten = entryFor(ranking, 'mizuho_rakuten_card')
          .programAwards
          .firstWhere((award) => award.programId.value == 'rakuten_point');
      expect(rakuten.points.points, 300);
    });

    test('上乗せはカテゴリではなく店舗単位で判定する（D-113）', () {
      final smbc =
          catalog.rewardRulesById[id('smbc_gold_nl_target_store_bonus')]!;
      expect(smbc.selectors.categoryIds, isEmpty);
      final smbcStores =
          smbc.selectors.merchantIds.map((x) => x.value).toList();
      expect(smbcStores, contains('seven_eleven'));
      expect(smbcStores, contains('mcdonalds'));
      expect(smbcStores, isNot(contains('family_mart')));

      final mufg = catalog.rewardRulesById[id('mufg_card_target_store_bonus')]!;
      final mufgStores =
          mufg.selectors.merchantIds.map((x) => x.value).toList();
      expect(mufgStores, contains('matsuya'));
      expect(mufgStores, isNot(contains('mcdonalds')));
      expect(mufgStores, isNot(contains('family_mart')));
    });

    test('利用頻度の高い7店舗は復活し、残りの4店舗は削除のまま（D-133・D-137）', () {
      final doc = readCatalogDocument('merchants.json');
      final ids = (doc['items']! as List)
          .cast<Map<String, dynamic>>()
          .map((item) => item['id'] as String)
          .toSet();
      for (final mid in <String>[
        'family_mart',
        'tenkaippin',
        'aeon',
        'mercari',
        'yahoo_shopping',
        'yodobashi',
        'biccamera',
      ]) {
        expect(ids, contains(mid));
      }
      for (final mid in <String>['life', 'seijo_ishii', 'pizza_la', 'pizzala']) {
        expect(ids, isNot(contains(mid)));
      }
    });

    test('ルールが参照する店舗はすべて存在する', () {
      for (final rule in catalog.rewardRulesById.values) {
        for (final merchantId in rule.selectors.merchantIds) {
          expect(
            directory.merchants.any((m) => m.id.value == merchantId.value),
            isTrue,
            reason: '${rule.id.value} -> ${merchantId.value}',
          );
        }
      }
    });

    test('松屋は三菱UFJカードだけ7%で、三井住友カード／Oliveは基本還元', () {
      final ranking = compareAt('matsuya');

      expect(entryFor(ranking, 'mufg_card').totalPoints.points, 140);
      expect(entryFor(ranking, 'smbc_gold_nl_card').totalPoints.points, 50);
      expect(entryFor(ranking, 'olive_flexible_pay_gold').totalPoints.points, 50);
    });

    test('JCB優待店はポイントアップ登録時に倍率どおりになる（要登録・2026-09-28時点）', () {
      // JCBのポイントアップルールはカタログ収載日（validFrom=2026-09-28）以降が対象。
      final jcbDate = date('2026-09-28');

      ConditionEvaluationContext registered() {
        return ConditionEvaluationContext(
          states: <StableId, TriState>{
            id('mizuho_w_point_plan_eligible'): TriState.satisfied,
            id('jcb_point_up_registered'): TriState.satisfied,
          },
        );
      }

      // 店舗ID -> 200円あたりの期待ポイント（倍率どおり）
      const expected = <String, int>{
        'sukiya': 21,        // 20倍
        'card_ride': 21,     // 20倍（クレカ乗車）
        'gusto': 21,         // 20倍
        'seven_eleven': 4,   // 3倍
        'amazon_jp': 4,      // 3倍
        'aoyama_tailor': 6,  // 5倍
        'uber': 11,          // 10倍
      };

      for (final entry in expected.entries) {
        final shop = merchant(entry.key);
        final ranking = evaluator.evaluate(
          catalog: catalog,
          amount: yen(200),
          transactionDate: jcbDate,
          merchantId: shop.id,
          merchantGroupIds: shop.groupIds,
          categoryIds: shop.categoryIds,
          conditionContext: registered(),
        );

        expect(
          entryFor(ranking, 'jcb_card_w').totalPoints.points,
          entry.value,
          reason: '${entry.key} は ${entry.value}pt（200円あたり）',
        );
      }
    });

    test('クレカ乗車はOliveが8%・SMBCが7%・JCBが10%になる（D-132）', () {
      final shop = merchant('card_ride');
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(200),
        transactionDate: date('2026-09-29'),
        merchantId: shop.id,
        merchantGroupIds: shop.groupIds,
        categoryIds: shop.categoryIds,
        conditionContext: ConditionEvaluationContext(
          states: <StableId, TriState>{
            id('mizuho_w_point_plan_eligible'): TriState.satisfied,
            id('jcb_point_up_registered'): TriState.satisfied,
          },
        ),
      );

      // 200円あたり: Olive 16pt（8%）、SMBC 14pt（7%）、JCB 20pt（10%）。
      expect(entryFor(ranking, 'olive_flexible_pay_gold').totalPoints.points, 16);
      expect(entryFor(ranking, 'smbc_gold_nl_card').totalPoints.points, 14);
      expect(entryFor(ranking, 'jcb_card_w').totalPoints.points, 21);
      expect(entryFor(ranking, 'v_neobank_debit').totalPoints.points, 3,
          reason: 'V NEOBANKデビット（1.5%）は乗車の上乗せ対象ではない');
    });

    test('ポイントアップ未登録ならJCBカードWの優待店上乗せは効かない', () {
      final shop = merchant('sukiya');
      final ranking = evaluator.evaluate(
        catalog: catalog,
        amount: yen(200),
        transactionDate: date('2026-09-28'),
        merchantId: shop.id,
        merchantGroupIds: shop.groupIds,
        categoryIds: shop.categoryIds,
        conditionContext: satisfiedContext(),
      );

      expect(entryFor(ranking, 'jcb_card_w').totalPoints.points, 2);
    });
  });

  group('2026.09.29.3 の追加・復活（D-137・D-138）', () {
    test('復活した7店舗が店舗カタログにある', () {
      final doc = readCatalogDocument('merchants.json');
      final ids = (doc['items']! as List)
          .cast<Map<String, dynamic>>()
          .map((item) => item['id'] as String)
          .toSet();
      for (final mid in <String>[
        'family_mart',
        'tenkaippin',
        'aeon',
        'mercari',
        'yahoo_shopping',
        'yodobashi',
        'biccamera',
      ]) {
        expect(ids, contains(mid));
      }
    });

    test('見逃していた高還元店舗の上乗せルールが登録されている', () {
      final rule = catalog.rewardRulesById[id('jcb_card_w_point_up_starbucks')]!;
      expect(rule.status.value, 'active');
      expect(
        rule.selectors.merchantIds.map((e) => e.value).toList(),
        <String>['starbucks'],
      );
      for (final rid in <String>[
        'jcb_card_w_point_up_disney_plus',
        'jcb_card_w_point_up_times_road_service',
        'jcb_card_w_point_up_owndays',
        'jcb_card_w_point_up_budget_rentacar',
        'jcb_card_w_point_up_keio_department',
        'jcb_card_w_point_up_daishin_drug',
        'jcb_card_w_point_up_hummingbird',
        'jcb_card_w_point_up_paru_ezuriko',
        'jcb_card_w_point_up_look_contact',
        'jcb_card_w_point_up_fukudaya',
      ]) {
        expect(catalog.rewardRulesById.containsKey(id(rid)), isTrue, reason: rid);
      }
    });

    test('Vitalityは4段階、SMBC日興証券は2条件に分かれている', () {
      for (final rid in <String>[
        'smbc_card_smbc_pup_vitality_gold_bonus',
        'smbc_card_smbc_pup_vitality_silver_bonus',
        'smbc_card_smbc_pup_vitality_bronze_bonus',
        'smbc_card_smbc_pup_vitality_blue_bonus',
        'smbc_card_smbc_pup_nikko_tsumitate_bonus',
        'smbc_card_smbc_pup_nikko_nisa_bonus',
      ]) {
        expect(catalog.rewardRulesById.containsKey(id(rid)), isTrue, reason: rid);
      }
      expect(
        catalog.rewardRulesById
            .containsKey(id('smbc_card_smbc_pup_sumitomo_life_vitality_bonus')),
        isFalse,
      );
      expect(
        catalog.rewardRulesById.containsKey(id('smbc_card_smbc_pup_smbc_nikko_bonus')),
        isFalse,
      );

      final doc = readCatalogDocument('condition_definitions.json');
      final ids = (doc['items']! as List)
          .cast<Map<String, dynamic>>()
          .map((item) => item['id'] as String)
          .toSet();
      expect(ids, contains('smbc_pup_vitality_gold'));
      expect(ids, contains('smbc_pup_vitality_blue'));
      expect(ids, contains('smbc_pup_nikko_nisa'));
    });
  });
}

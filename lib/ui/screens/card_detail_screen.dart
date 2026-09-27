import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/payment_instrument_models.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import 'card_management_screen.dart';
import 'condition_settings_screen.dart';
import '../widgets/logo_tile.dart';

/// カードの詳細画面（D-096）。
///
/// ランキングで表示されたカードをタップすると開く。年会費・基本還元・
/// 店舗上乗せ・注意事項を1枚にまとめる。数値はカタログをそのまま読み、
/// 画面側で足し算や推測はしない。
final class CardDetailScreen extends StatelessWidget {
  const CardDetailScreen({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RankingController>();
    final theme = Theme.of(context);

    final instrument = _find(controller.catalog.paymentInstrumentsById.values);
    if (instrument == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('カードの詳細')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Text('このカードの情報が見つかりません。'),
        ),
      );
    }

    final rules = _rulesFor(controller, instrument.id.value);

    return Scaffold(
      appBar: AppBar(title: Text(instrument.shortName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              LogoTile(
                assetPath: cardLogoPath(instrument.id.value),
                label: instrument.name,
                size: 72,
                padding: 4,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(instrument.name, style: theme.textTheme.titleMedium),
                    Text(instrument.issuerName, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBasicInfo(theme, instrument),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CardManagementScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.credit_card),
                  label: const Text('カード管理で設定'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ConditionSettingsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.tune),
                  label: const Text('還元率の基準'),
                ),
              ),
            ],
          ),
          if (controller.conditionOptions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text('還元率の基準（いまの設定）', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final option in controller.conditionOptions)
              Text(
                '・${option.name}: ${_stateLabel(controller.conditionStateOf(option.id))}',
                style: theme.textTheme.bodySmall,
              ),
          ],
          const SizedBox(height: 16),
          Text('還元のしくみ', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final rule in rules) _buildRuleCard(theme, rule),
          if (rules.isEmpty)
            const Text('このカードの還元ルールはまだ登録されていません。'),
          if (instrument.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text('注意事項', style: theme.textTheme.titleMedium),
            for (final note in instrument.notes)
              Text('・$note', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          Text(
            '※ 表示はカタログに登録された内容です。最新の条件は各社の公式情報をご確認ください。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  PaymentInstrument? _find(Iterable<PaymentInstrument> instruments) {
    for (final instrument in instruments) {
      if (instrument.id.value == instrumentId) {
        return instrument;
      }
    }

    return null;
  }

  List<RewardRule> _rulesFor(RankingController controller, String id) {
    final rules = <RewardRule>[
      for (final rule in controller.catalog.rewardRulesById.values)
        if (rule.selectors.instrumentIds.any((value) => value.value == id))
          rule,
    ]..sort(
        (left, right) =>
            left.stacking.applicationOrder.compareTo(right.stacking.applicationOrder),
      );

    return rules;
  }

  Widget _buildBasicInfo(ThemeData theme, PaymentInstrument instrument) {
    final fee = instrument.annualFee.yen == 0
        ? '無料'
        : '${_group(instrument.annualFee.yen)}円';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _row(theme, '年会費', fee),
            _row(
              theme,
              '種類',
              switch (instrument.instrumentType) {
                'creditCard' => 'クレジットカード',
                'debitCard' => 'デビットカード',
                _ => instrument.instrumentType,
              },
            ),
            if (instrument.partnerInstitutionName != null)
              _row(theme, '提携', instrument.partnerInstitutionName!),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildRuleCard(ThemeData theme, RewardRule rule) {
    final isDraft = rule.status == CatalogItemStatus.draft;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(rule.name, style: theme.textTheme.titleSmall),
                ),
                if (isDraft) const Chip(label: Text('第2期')),
              ],
            ),
            const SizedBox(height: 4),
            Text(_describe(rule), style: theme.textTheme.bodyMedium),
            Text(
              '集計: ${_scopeLabel(rule.aggregation.scope)}',
              style: theme.textTheme.bodySmall,
            ),
            if (rule.cap == null && rule.ruleKind != RewardRuleKind.baseReward)
              Text(
                '※ 進呈上限はまだ計算に反映されていません。',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  /// ルールの計算内容を日本語1行にする。数値の再計算はしない。
  String _describe(RewardRule rule) {
    final calculation = rule.calculation;

    return switch (calculation) {
      UnitPointsRewardCalculation() =>
        '${_group(calculation.amountUnit.yen)}円につき'
            '${calculation.pointsPerUnit.points}ポイント',
      RateFractionRewardCalculation() =>
        '還元率 ${_formatRate(calculation.rate)}',
      ThresholdBonusRewardCalculation() =>
        '${_group(calculation.thresholdAmount.yen)}円の利用で'
            '${calculation.bonusPoints.points}ポイント',
      MirrorRewardCalculation() => '基本還元と同じ数だけ加算',
      FixedPointsRewardCalculation() =>
        '${calculation.points.points}ポイント',
      _ => rule.description,
    };
  }

  String _scopeLabel(RewardAggregationScope scope) {
    return switch (scope) {
      RewardAggregationScope.transaction => '1回の支払いごと',
      RewardAggregationScope.calendarMonth => '暦月（1日〜末日）',
      RewardAggregationScope.billingMonth => '請求期間（16日〜翌月15日）',
      RewardAggregationScope.membershipYear => '入会からの1年ごと',
      _ => scope.value,
    };
  }

  static String _stateLabel(TriState state) {
    return switch (state) {
      TriState.satisfied => '満たす',
      TriState.notSatisfied => '満たさない',
      TriState.unknown => '不明（確定値に含めない）',
      TriState.notApplicable => '対象外',
    };
  }

  static String _group(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < text.length; index++) {
      if (index > 0 && (text.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(text[index]);
    }

    return buffer.toString();
  }

  static String _formatRate(Rational rate) {
    final hundredths =
        (BigInt.from(rate.numerator) * BigInt.from(10000)) ~/
            BigInt.from(rate.denominator);
    final whole = hundredths ~/ BigInt.from(100);
    final fraction = (hundredths % BigInt.from(100)).toString().padLeft(2, '0');

    return '$whole.$fraction%';
  }
}

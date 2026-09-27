import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/domain/ranking/reward_ranking.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';

/// 選んだ店舗で「いちばん得なカード」を出す画面（D-088〜D-090）。
///
/// 金額は入力させない。還元率で比べ、基準（みずほ楽天カード）を上回る
/// カードがあるときだけ上位を示す。
final class MerchantCompareScreen extends StatelessWidget {
  const MerchantCompareScreen({super.key, required this.merchant});

  final MerchantEntry merchant;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RankingController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(merchant.name)),
      body: controller.ranking == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _buildConclusion(context, controller.ranking!),
                const SizedBox(height: 16),
                Text('カードごとの比較', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '1万円の支払いで換算した還元率です（金額の入力は不要）。',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (final entry in controller.ranking!.allEntries)
                  _buildEntry(context, entry),
                if (merchant.notes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('この店での条件', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          for (final note in merchant.notes)
                            Text('・$note', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  '※ 進呈上限と、ポイントアッププログラムの条件達成は'
                  'まだ計算に入っていません。',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '計算結果は参考値です。実際の還元は各社の公式情報をご確認ください。',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
    );
  }

  Widget _buildConclusion(BuildContext context, RewardRanking ranking) {
    final theme = Theme.of(context);
    final baseline = ranking.baselineEntry;
    final better = ranking.betterThanBaseline;
    final colorScheme = theme.colorScheme;

    if (baseline == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('基準にするみずほ楽天カードがカード一覧にありません。'),
        ),
      );
    }

    final isBaselineBest = better.isEmpty;
    final winner = isBaselineBest ? baseline : better.first;
    final headline = isBaselineBest
        ? '${baseline.instrumentName}で支払う'
        : '${winner.instrumentName}で支払う';
    final reason = isBaselineBest
        ? 'この店でこれを上回るカードはありません。'
        : '基準（${baseline.instrumentName}）より '
            '+${_formatRateDelta(winner, baseline)} 得です。';

    return Card(
      color: isBaselineBest
          ? colorScheme.surfaceContainerHighest
          : colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  isBaselineBest ? Icons.check_circle : Icons.star,
                  color: isBaselineBest
                      ? colorScheme.primary
                      : colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(headline, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '還元率 ${_formatRate(winner.effectiveRate)}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(reason),
            if (better.length > 1) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'ほかにも上回るカードが${better.length - 1}枚あります。',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(BuildContext context, RewardRankingEntry entry) {
    final theme = Theme.of(context);

    return Card(
      shape: entry.isBaseline
          ? RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.primary),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.instrumentName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (entry.isBaseline) const Chip(label: Text('基準')),
                if (entry.beatsBaseline) const Chip(label: Text('基準超え')),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '還元率 ${_formatRate(entry.effectiveRate)}'
              '（1万円で +${_formatMicrosYen(entry.confirmedValue)}円相当）',
            ),
            if (!entry.isBaseline)
              Text(
                '基準との差 ${_formatDelta(MicrosYen(entry.baselineDeltaMicros))}',
                style: theme.textTheme.bodySmall,
              ),
            if (entry.programAwards.isNotEmpty)
              Text(
                entry.programAwards
                    .map((award) =>
                        '${award.programName} ${award.points.points}${award.unitName}')
                    .join('／'),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

String _formatRateDelta(RewardRankingEntry winner, RewardRankingEntry baseline) {
  return _formatMicrosYen(
    MicrosYen(winner.baselineDeltaMicros < 0 ? 0 : winner.baselineDeltaMicros),
  );
}

String _formatDelta(MicrosYen value) {
  final formatted = _formatMicrosYen(MicrosYen(value.micros.abs()));

  if (value.micros > 0) {
    return '+$formatted円';
  }

  if (value.micros < 0) {
    return '-$formatted円';
  }

  return '±0円';
}

String _formatMicrosYen(MicrosYen value) {
  final micros = value.micros;
  final negative = micros < 0;
  final absolute = micros.abs();
  final whole = absolute ~/ MicrosYen.microsPerYen;
  final fraction = absolute % MicrosYen.microsPerYen;
  final buffer = StringBuffer();

  if (negative) {
    buffer.write('-');
  }
  buffer.write(whole);

  if (fraction != 0) {
    final decimals = (fraction ~/ 10000).toString().padLeft(2, '0');
    buffer
      ..write('.')
      ..write(decimals);
  }

  return buffer.toString();
}

String _formatRate(Rational rate) {
  final hundredths =
      (BigInt.from(rate.numerator) * BigInt.from(10000)) ~/
          BigInt.from(rate.denominator);
  final whole = hundredths ~/ BigInt.from(100);
  final fraction = (hundredths % BigInt.from(100)).toString().padLeft(2, '0');

  return '$whole.$fraction%';
}

import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/domain/ranking/reward_ranking.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../widgets/logo_tile.dart';
import '../screens/card_detail_screen.dart';

/// 計算タブ（D-115）。
///
/// 金額と店舗を選ぶと、その店舗でその金額を払ったときに
/// カードごとに何円還元されるかを出す。
final class CalculatorTab extends StatefulWidget {
  const CalculatorTab({super.key});

  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

final class _CalculatorTabState extends State<CalculatorTab> {
  final TextEditingController _amountController = TextEditingController();
  MerchantEntry? _merchant;
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RankingController>();
    final theme = Theme.of(context);
    final ranking = controller.ranking;

    return Scaffold(
      appBar: AppBar(title: const Text('計算')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            '金額とお店を選ぶと、そのお店で何円還元されるかを出します。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: '支払う金額（円）',
              hintText: '例: 3000',
              border: const OutlineInputBorder(),
              errorText: _errorText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final amount in <int>[500, 1000, 3000, 5000, 10000])
                ActionChip(
                  label: Text('${_group(amount)}円'),
                  onPressed: () {
                    _amountController.text = amount.toString();
                    _recompute();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: Text(_merchant?.name ?? 'お店を選ぶ'),
              subtitle: Text(
                _merchant == null
                    ? 'タップして店舗を選んでください'
                    : 'この店で計算します',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickMerchant(controller),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _recompute,
            icon: const Icon(Icons.calculate),
            label: const Text('還元額を計算'),
          ),
          const SizedBox(height: 20),
          if (ranking == null || _merchant == null)
            Text(
              '金額とお店を選んで「還元額を計算」を押すと、ここに結果が出ます。',
              style: theme.textTheme.bodySmall,
            )
          else ...<Widget>[
            _buildWinner(context, ranking),
            const SizedBox(height: 16),
            Text('カードごとの還元額', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${_group(ranking.amount.yen)}円を「${_merchant!.name}」で支払った場合',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final entry in ranking.allEntries)
              _buildEntry(context, entry),
            const SizedBox(height: 12),
            Text(
              '※ 進呈上限（月50,000ポイント等）と、期間ごとの対象金額上限'
              '（三菱UFJカードの50,000円等）はまだ計算に入っていません。',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '※ ポイントの価値は1ポイント=1円（グローバルポイントは5円）'
              'で換算しています。実際の還元は各社の公式情報をご確認ください。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWinner(BuildContext context, RewardRanking ranking) {
    final theme = Theme.of(context);
    final winner = ranking.bestEntry;

    if (winner == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('このお店で計算できるカードがありません。'),
        ),
      );
    }

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CardDetailScreen(
              instrumentId: winner.instrumentId.value,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: <Widget>[
              LogoTile(
                assetPath: cardLogoPath(winner.instrumentId.value),
                label: winner.instrumentName,
                size: 88,
                padding: 6,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('いちばん得', style: theme.textTheme.labelLarge),
                    Text(
                      winner.instrumentName,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_group(winner.confirmedValue.yenRounded)}円還元',
                      style: theme.textTheme.headlineSmall,
                    ),
                    Text(
                      '${_formatRate(winner.effectiveRate)}'
                      '／${_formatPoints(winner)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntry(BuildContext context, RewardRankingEntry entry) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: entry.isBaseline
          ? RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.primary),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CardDetailScreen(
              instrumentId: entry.instrumentId.value,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              LogoTile(
                assetPath: cardLogoPath(entry.instrumentId.value),
                label: entry.instrumentName,
                size: 64,
                padding: 4,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.instrumentName,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '${_group(entry.confirmedValue.yenRounded)}円還元'
                      '（${_formatRate(entry.effectiveRate)}）',
                      style: theme.textTheme.bodyLarge,
                    ),
                    Text(
                      _formatPoints(entry),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (entry.isBaseline)
                      Text(
                        '基準のカード',
                        style: theme.textTheme.labelSmall,
                      ),
                    if (entry.hasUnresolvedConditions)
                      Text(
                        '※ 未設定の条件があります（設定タブで選べます）',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 店舗を選ばせる。
  void _pickMerchant(RankingController controller) {
    final categories = controller.orderedCategories;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('店舗がまだ読み込まれていません。')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          children: <Widget>[
            for (final category in categories) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  category.name,
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
              ),
              for (final merchant
                  in controller.merchantsInCategoryOrdered(category.id))
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(merchant.name),
                  trailing: Text(
                    controller.bestRateLabelAt(merchant),
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() => _merchant = merchant);
                    _recompute(merchant: merchant);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _recompute({MerchantEntry? merchant}) {
    final target = merchant ?? _merchant;
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;

    if (target == null) {
      setState(() => _errorText = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お店を選んでください。')),
      );
      return;
    }

    if (amount < 1) {
      setState(() => _errorText = '1円以上の整数を入力してください。');
      return;
    }

    setState(() => _errorText = null);
    context.read<RankingController>().compareAtMerchantWithAmount(
          merchant: target,
          amount: MoneyYen(amount),
        );
  }
}

String _formatPoints(RewardRankingEntry entry) {
  if (entry.programAwards.isEmpty) {
    return 'ポイントなし';
  }

  return entry.programAwards
      .map((award) => '${award.programName} ${award.points.points}${award.unitName}')
      .join('／');
}

String _formatRate(Rational rate) {
  final hundredths = (BigInt.from(rate.numerator) * BigInt.from(10000)) ~/
      BigInt.from(rate.denominator);
  final whole = hundredths ~/ BigInt.from(100);
  final fraction = (hundredths % BigInt.from(100)).toString().padLeft(2, '0');

  return '$whole.$fraction%';
}

String _group(int value) {
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

/// `MicrosYen` の円未満を四捨五入した整数（表示用）。
extension on MicrosYen {
  int get yenRounded {
    final micros = this.micros;
    final half = MicrosYen.microsPerYen ~/ 2;
    return (micros + half) ~/ MicrosYen.microsPerYen;
  }
}

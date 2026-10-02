import 'package:flutter/material.dart';

import '../widgets/charts.dart';

/// 円グラフの内訳を大きく見る画面（D-167）。
///
/// 年間タブの円グラフをタップすると開く。利用金額と還元金額のみを一覧表示し、
/// 会計の明細（いつ・どこで）は表示しない。月ごとの内訳画面とは別の画面。
final class BreakdownDetailScreen extends StatelessWidget {
  const BreakdownDetailScreen({
    super.key,
    required this.title,
    required this.items,
    required this.pieBySpend,
    required this.pieLabel,
  });

  final String title;
  final List<BreakdownItem> items;

  /// 円グラフを利用金額で描くなら true、還元金額で描くなら false。
  final bool pieBySpend;

  /// 円グラフ中央の見出し（「利用額」「還元額」）。
  final String pieLabel;

  int _metric(BreakdownItem item) => pieBySpend ? item.spendYen : item.rewardYen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordered = items.toList()
      ..sort((a, b) => _metric(b).compareTo(_metric(a)));
    final total = ordered.fold<int>(0, (sum, item) => sum + _metric(item));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ordered.isEmpty
          ? const Center(child: Text('内訳はありません。'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Center(
                  child: SimplePieChart(
                    slices: <PieSlice>[
                      for (final item in ordered)
                        PieSlice(
                          label: item.label,
                          value: _metric(item),
                          color: item.color,
                        ),
                    ],
                    size: 220,
                    centerTitle: pieLabel,
                    centerValue: '${_group(total)}円',
                    showLegend: false,
                  ),
                ),
                const SizedBox(height: 16),
                Text('内訳', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '利用金額と還元金額を、多い順に並べています。'
                  '会計ごとの明細は、月の内訳画面で確認できます。',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (final item in ordered) _row(theme, item, total),
              ],
            ),
    );
  }

  Widget _row(ThemeData theme, BreakdownItem item, int total) {
    final metric = _metric(item);
    final percent = total <= 0
        ? 0
        : (metric * 1000 / total).round() ~/ 10;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.label, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      Text(
                        '利用 ${_group(item.spendYen)}円',
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '還元 ${_group(item.rewardYen)}円',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: rewardOrange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '$percent%',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
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

import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../widgets/logo_tile.dart';

/// 年間タブ（D-102）。
///
/// 金額を入力するのはこのタブだけ（店舗タブでは入力しない・D-088）。
/// 年間の利用額から、カードごとの年間概算と年会費無料の到達状況を示す。
final class YearlyTab extends StatefulWidget {
  const YearlyTab({super.key});

  @override
  State<YearlyTab> createState() => _YearlyTabState();
}

final class _YearlyTabState extends State<YearlyTab> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RankingController>();
    final theme = Theme.of(context);
    final summary = controller.annualSummary;

    return Scaffold(
      appBar: AppBar(title: const Text('年間')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            '年間で使う金額を入れると、カードごとの年間の還元額を概算します。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: '年間の利用額（円）',
              hintText: '例: 1200000',
              border: const OutlineInputBorder(),
              errorText: _errorText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final amount in <int>[600000, 1000000, 1500000, 2000000])
                ActionChip(
                  label: Text('${_group(amount)}円'),
                  onPressed: () => _submit(amount),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () =>
                _submit(int.tryParse(_controller.text.trim()) ?? 0),
            icon: const Icon(Icons.calculate),
            label: const Text('年間の還元額を計算'),
          ),
          const SizedBox(height: 20),
          if (summary == null)
            Text(
              '金額を入れて計算すると、ここに結果が出ます。',
              style: theme.textTheme.bodySmall,
            )
          else ...<Widget>[
            Text(
              '年間の概算（利用額 ${_group(summary.annualSpend.yen)}円）',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '※ 年間の利用額をまとめて1回計算した概算です。'
              '進呈上限と対象店舗の上乗せは含まれません。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final entry in summary.ordered)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      LogoTile(
                        assetPath: cardLogoPath(entry.instrumentId.value),
                        label: entry.instrumentName,
                        size: 56,
                        padding: 3,
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
                              '還元率 約${_formatRate(entry.effectiveRate)}'
                              '／+${_formatYen(entry.totalValue)}円相当',
                            ),
                            Text(
                              '基本 ${_formatYen(entry.baseValue)}円'
                              '＋年間ボーナス ${_formatYen(entry.bonusValue)}円',
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              entry.annualFee.yen == 0
                                  ? '年会費 無料'
                                  : '年会費 ${_group(entry.annualFee.yen)}円'
                                      '${entry.feeWaivedNextYear ? '（翌年以降は無料）' : ''}',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (entry.hasUnresolvedConditions)
                              Text(
                                '※ 未入力の条件があります（還元率の基準で設定できます）',
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              '計算結果は参考値です。実際の還元は各社の公式情報をご確認ください。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  void _submit(int amount) {
    if (amount < 1) {
      setState(() => _errorText = '1円以上の整数を入力してください。');
      return;
    }

    setState(() => _errorText = null);
    context.read<RankingController>().computeAnnualSummary(
          annualSpend: MoneyYen(amount),
        );
  }
}

String _formatYen(MicrosYen value) {
  final micros = value.micros;
  final whole = micros ~/ MicrosYen.microsPerYen;
  final fraction = micros % MicrosYen.microsPerYen;
  final text = _group(whole);

  if (fraction == 0) {
    return text;
  }

  return '$text.${(fraction ~/ 10000).toString().padLeft(2, '0')}';
}

String _formatRate(Rational rate) {
  final hundredths =
      (BigInt.from(rate.numerator) * BigInt.from(10000)) ~/
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

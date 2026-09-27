import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../widgets/empty_catalog_notice.dart';

/// ホームタブ。アプリの状態と使い方を示す。
final class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<RankingController>();

    return Scaffold(
      appBar: AppBar(title: const Text('BESTpay')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('ようこそ BESTpay へ', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'レジ前で店舗を選ぶだけで、いちばん得なカードが分かります。\n'
            '金額の入力は不要です（年間の集計は「年間」タブで行います）。',
          ),
          const SizedBox(height: 16),
          if (controller.isCatalogEmpty)
            EmptyCatalogNotice(missingFiles: controller.missingCatalogFiles)
          else ...<Widget>[
            Card(
              child: ListTile(
                leading: const Icon(Icons.credit_card),
                title: Text(
                  '登録カード: '
                  '${controller.catalog.paymentInstrumentsById.length} 枚',
                ),
                subtitle: Text(
                  'ランキング対象: '
                  '${controller.catalog.paymentInstrumentsById.values.where((card) => controller.isCardVisible(card.id.value)).length} 枚',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront),
                title: Text('登録店舗: ${controller.directory.merchants.length} 店'),
                subtitle: const Text('「店舗」タブから選んでください'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('還元率の基準（条件）'),
                subtitle: Text(
                  controller.conditionOptions.isEmpty
                      ? '設定できる条件はまだありません'
                      : '「設定」タブから変更できます',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

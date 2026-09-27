import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../widgets/empty_catalog_notice.dart';

/// ホームタブ。アプリの入口と現在の状態を表示する。
final class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('BESTpay')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('ようこそ BESTpay へ', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            '店舗と金額を入れると、保有カードの還元額ランキングを表示します。\n'
            'まずは「店舗」タブから試してください。',
          ),
          const SizedBox(height: 16),
          Consumer<AppState>(
            builder: (context, appState, _) {
              final catalog = appState.catalog;
              if (catalog.isEmpty) {
                return const EmptyCatalogNotice();
              }
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: Text('登録カード: ${catalog.cards.length} 枚'),
                  subtitle: const Text('カタログ読み込み済み'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../widgets/empty_catalog_notice.dart';

/// カード管理画面（最小版）。
///
/// カタログに登録された保有カードの一覧を表示する。
/// カードの追加・編集 UI は次フェーズ。追加手順そのものは
/// docs/decisions/card_addition_runbook.md を参照。
final class CardManagementScreen extends StatelessWidget {
  const CardManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カード管理')),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final catalog = appState.catalog;
          if (catalog.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyCatalogNotice(),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: catalog.cards.length,
            itemBuilder: (context, index) {
              final card = catalog.cards[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: Text(card.displayName),
                  subtitle: Text(card.id.value),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

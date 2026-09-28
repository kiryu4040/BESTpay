import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../screens/category_order_screen.dart';
import '../screens/condition_settings_screen.dart';
import '../screens/merchant_order_screen.dart';
import '../screens/card_management_screen.dart';

/// 設定タブ。カード管理・条件設定・並べ替えへの入口をまとめる（D-104）。
final class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RankingController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.credit_card),
            title: const Text('カード管理'),
            subtitle: const Text('保有カードの一覧・ランキングへの表示'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CardManagementScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('カードごとの条件'),
            subtitle: Text(
              controller.conditionOptions.isEmpty
                  ? '設定できる条件はまだありません'
                  : 'カード別に、当てはまる条件をオンにします',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ConditionSettingsScreen(),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('カテゴリの並べ替え'),
            subtitle: const Text('店舗タブのカテゴリの順番'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CategoryOrderScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.reorder),
            title: const Text('店舗の並べ替え'),
            subtitle: const Text('カテゴリの中の店舗の順番'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickCategory(context, controller),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('このアプリについて'),
            subtitle: const Text('BESTpay v2（個人利用）'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'BESTpay',
                applicationVersion: '2.0.0',
                children: <Widget>[
                  Text(
                    '店舗を選ぶだけで、いちばん得なカードを示す個人利用アプリ。'
                    '基準はみずほ楽天カードです。',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 並べ替えるカテゴリを選ばせる。
  void _pickCategory(BuildContext context, RankingController controller) {
    final categories = controller.orderedCategories;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('並べ替えるカテゴリがありません。')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: <Widget>[
          const ListTile(
            title: Text('並べ替えるカテゴリを選ぶ'),
            dense: true,
          ),
          for (final category in categories)
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(category.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MerchantOrderScreen(category: category),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

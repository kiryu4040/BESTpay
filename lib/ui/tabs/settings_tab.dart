import 'package:flutter/material.dart';

import '../screens/card_management_screen.dart';

/// 設定タブ。カード管理への入口とアプリ情報を表示する。
final class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.credit_card),
            title: const Text('カード管理'),
            subtitle: const Text('保有カードの一覧'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CardManagementScreen(),
                ),
              );
            },
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
                children: const <Widget>[
                  Text('店舗と金額から最適なカードを選ぶ個人利用アプリ。'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

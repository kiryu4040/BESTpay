import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/store.dart';
import '../providers/app_state.dart';
import 'category_screen.dart';
import 'condition_screen.dart';
import 'custom_rule_screen.dart';
import 'payment_list_screen.dart';
import 'settings_screen.dart';
import 'simulation_screen.dart';
import 'store_detail_screen.dart';
import 'store_search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = const [
      ('convenience', '🏪', 'コンビニ'),
      ('restaurant', '🍝', 'ファミレス'),
      ('cafe', '☕', 'カフェ'),
      ('drugstore', '💊', 'ドラッグ'),
      ('supermarket', '🛒', 'スーパー'),
      ('ec', '📦', 'EC・ネット'),
      ('transit', '🚊', '交通'),
      ('department', '🏬', '百貨店'),
      ('discount', '💯', '100均'),
      ('gas', '⛽', 'ガソリン'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('BestPay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StoreSearchScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Icon(Icons.search,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(
                    '店舗を検索...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 6),
              Text('お気に入り',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          if (state.favorites.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('店舗詳細画面の★で追加できます',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.favorites.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = state.favorites[i];
                  return _FavoriteChip(store: s);
                },
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.category_outlined, size: 20),
              const SizedBox(width: 6),
              Text('カテゴリから探す',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final c = categories[i];
              return _CategoryTile(category: c.$1, icon: c.$2, label: c.$3);
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.bolt_outlined, size: 20),
              const SizedBox(width: 6),
              Text('クイック操作',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          _QuickTile(
            icon: Icons.credit_card,
            title: '保有決済方法の管理',
            subtitle: 'カード・QR決済のON/OFF',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PaymentListScreen())),
          ),
          _QuickTile(
            icon: Icons.checklist,
            title: '条件達成状況の管理',
            subtitle: 'Vポイントアップ・PayPayステップ等',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ConditionScreen())),
          ),
          _QuickTile(
            icon: Icons.tune,
            title: 'カスタムルール',
            subtitle: '独自の還元率を登録',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CustomRuleScreen())),
          ),
          _QuickTile(
            icon: Icons.calculate_outlined,
            title: '積立還元シミュレーション',
            subtitle: '月次・年次の還元額予測',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SimulationScreen())),
          ),
        ],
      ),
    );
  }
}

class _FavoriteChip extends StatelessWidget {
  final Store store;
  const _FavoriteChip({required this.store});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => StoreDetailScreen(storeId: store.id!)),
      ),
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(store.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              store.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String category;
  final String icon;
  final String label;
  const _CategoryTile(
      {required this.category, required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryScreen(category: category, title: label),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

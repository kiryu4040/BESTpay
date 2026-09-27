import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../widgets/empty_catalog_notice.dart';

/// 店舗×金額 → 保有カードの還元額ランキング画面（骨格）。
///
/// 計算エンジン（lib/domain/calculation/）は実装済みだが、
/// カード実データ（カタログ）が次フェーズのため、
/// 現状は空カタログ時の案内表示までを保証する。
final class StoreRankingScreen extends StatefulWidget {
  const StoreRankingScreen({super.key});

  @override
  State<StoreRankingScreen> createState() => _StoreRankingScreenState();
}

final class _StoreRankingScreenState extends State<StoreRankingScreen> {
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _submitted = false;

  @override
  void dispose() {
    _storeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('店舗で比較')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _storeController,
            decoration: const InputDecoration(
              labelText: '店舗名',
              hintText: '例: コンビニ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: '金額（円）',
              hintText: '例: 1000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _submitted = true;
              });
            },
            icon: const Icon(Icons.leaderboard),
            label: const Text('還元額ランキングを表示'),
          ),
          const SizedBox(height: 24),
          if (_submitted) _buildResult(context),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final catalog = context.read<AppState>().catalog;

    // カード0枚はクラッシュではなく案内を返す（v2 の設計要件）。
    if (catalog.isEmpty) {
      return const EmptyCatalogNotice();
    }

    // カタログが存在する場合の骨格。
    // 還元額の算出接続は次フェーズで行うため、現状はカード名のみ列挙する。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${_storeController.text} / ${_amountController.text} 円',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < catalog.cards.length; i++)
          Card(
            child: ListTile(
              leading: Text('${i + 1}'),
              title: Text(catalog.cards[i].displayName),
              subtitle: const Text('還元額の算出は次フェーズで接続予定'),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/catalog/models/payment_instrument_models.dart';
import '../ranking_controller.dart';
import '../widgets/empty_catalog_notice.dart';
import '../widgets/logo_tile.dart';
import 'card_detail_screen.dart';
import 'condition_settings_screen.dart';

/// カード管理画面（D-104）。
///
/// 保有カードの一覧、ランキングへの表示切り替え、条件設定への入口をまとめる。
/// カードの追加そのものはカタログ（アプリ同梱データ）で行う。
final class CardManagementScreen extends StatelessWidget {
  const CardManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RankingController>();
    final theme = Theme.of(context);

    if (controller.isCatalogEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('カード管理')),
        body: EmptyCatalogNotice(missingFiles: controller.missingCatalogFiles),
      );
    }

    final instruments = controller.catalog.paymentInstrumentsById.values.toList()
      ..sort((left, right) => left.id.value.compareTo(right.id.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('カード管理'),
        actions: <Widget>[
          IconButton(
            tooltip: '還元率の基準（条件）',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ConditionSettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const SizedBox(height: 8),
          for (final instrument in instruments)
            _buildCard(context, controller, instrument),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    RankingController controller,
    PaymentInstrument instrument,
  ) {
    final visible = controller.isCardVisible(instrument.id.value);
    final fee = instrument.annualFee.yen == 0
        ? '年会費 無料'
        : '年会費 ${_group(instrument.annualFee.yen)}円';

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CardDetailScreen(
              instrumentId: instrument.id.value,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              LogoTile(
                assetPath: cardLogoPath(instrument.id.value),
                label: instrument.name,
                size: 56,
                padding: 3,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      instrument.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      fee,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: visible,
                onChanged: (value) =>
                    controller.setCardVisible(instrument.id.value, value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _group(int value) {
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
}

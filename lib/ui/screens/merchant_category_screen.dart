import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../widgets/logo_tile.dart';
import 'merchant_compare_screen.dart';
import 'merchant_order_screen.dart';

/// カテゴリ内の店舗一覧。
///
/// 並び順は利用者が手で決める（設定タブの「店舗の並べ替え」・D-099）。
/// 名前順・カタログ順・還元率順といった自動の並べ替えは持たない（D-124）。
final class MerchantCategoryScreen extends StatelessWidget {
  const MerchantCategoryScreen({super.key, required this.category});

  final MerchantCategory category;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RankingController>();
    final merchants = controller.merchantsInCategoryOrdered(category.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        actions: <Widget>[
          IconButton(
            tooltip: '店舗の並べ替え',
            icon: const Icon(Icons.reorder),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MerchantOrderScreen(category: category),
              ),
            ),
          ),
        ],
      ),
      body: merchants.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('このカテゴリの店舗はまだありません。'),
            )
          : MerchantLogoGrid(
              merchants: merchants,
              onTap: (merchant) {
                context.read<RankingController>().compareAtMerchant(merchant);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MerchantCompareScreen(merchant: merchant),
                  ),
                );
              },
            ),
    );
  }
}

/// タイルに収まらない長い名前の略称（D-128）。
///
/// 世間でよく使われている呼び方を採用する。ここに無い店は正式名を出す。
const Map<String, String> merchantShortNames = <String, String>{
  'kfc': 'ケンタッキー',
  'doutor': 'ドトール',
  'excelsior': 'エクセルシオール',
  'starbucks': 'スタバ',
  'sanmark_cafe': 'サンマルク',
  'freshness_burger': 'フレッシュネス',
  'go_taxi': 'GO',
  'haruyama': 'はるやま',
  'akachan_honpo': 'アカチャン',
  'coca_cola_vending': 'コカ・コーラ',
  'card_ride': 'クレカ乗車',
};

/// タイルに出す店舗名（長い名前は略称にする）。
String merchantShortName(MerchantEntry merchant) {
  return merchantShortNames[merchant.id.value] ?? merchant.name;
}

/// 正方形ロゴを規則正しく並べるグリッド（D-092）。
final class MerchantLogoGrid extends StatelessWidget {
  const MerchantLogoGrid({
    super.key,
    required this.merchants,
    required this.onTap,
    this.rateLabel,
    this.shrinkWrap = false,
  });

  final List<MerchantEntry> merchants;
  final void Function(MerchantEntry merchant) onTap;

  /// タイル下に添える補足（必要なときだけ渡す）。
  final String Function(MerchantEntry merchant)? rateLabel;

  /// 親のスクロール内に置くときは true。
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.92,
      ),
      itemCount: merchants.length,
      itemBuilder: (context, index) {
        final merchant = merchants[index];

        // 並べ替えで位置が変わっても中身が取り違わらないようにキーを付ける。
        return InkWell(
          key: ValueKey<String>('merchant_tile_${merchant.id.value}'),
          onTap: () => onTap(merchant),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              LogoTile(
                assetPath: merchantLogoPath(merchant.id.value),
                label: merchant.name,
                size: 64,
              ),
              const SizedBox(height: 2),
              Text(
                merchantShortName(merchant),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (rateLabel != null)
                Text(
                  rateLabel!(merchant),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../widgets/logo_tile.dart';
import 'merchant_compare_screen.dart';

/// カテゴリ内の店舗一覧。並べ替えができる（D-093）。
final class MerchantCategoryScreen extends StatefulWidget {
  const MerchantCategoryScreen({super.key, required this.category});

  final MerchantCategory category;

  @override
  State<MerchantCategoryScreen> createState() => _MerchantCategoryScreenState();
}

/// 一覧の並べ替え方。
enum MerchantSortOrder {
  catalog('カタログ順'),
  name('名前順'),
  rate('還元率が高い順');

  const MerchantSortOrder(this.label);

  final String label;
}

final class _MerchantCategoryScreenState extends State<MerchantCategoryScreen> {
  MerchantSortOrder _order = MerchantSortOrder.catalog;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RankingController>();
    final merchants = _sortedMerchants(controller);

    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: <Widget>[
                for (final order in MerchantSortOrder.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(order.label),
                      selected: _order == order,
                      onSelected: (_) => setState(() => _order = order),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: merchants.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('このカテゴリの店舗はまだありません。'),
                  )
                : MerchantLogoGrid(
                    merchants: merchants,
                    rateLabel: _order == MerchantSortOrder.rate
                        ? controller.bestRateLabelAt
                        : null,
                    onTap: (merchant) {
                      context.read<RankingController>().compareAtMerchant(merchant);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MerchantCompareScreen(merchant: merchant),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<MerchantEntry> _sortedMerchants(RankingController controller) {
    final merchants = controller.directory
        .merchantsInCategory(widget.category.id)
        .toList();

    switch (_order) {
      case MerchantSortOrder.catalog:
        break;
      case MerchantSortOrder.name:
        merchants.sort((left, right) => left.name.compareTo(right.name));
      case MerchantSortOrder.rate:
        merchants.sort((left, right) {
          final byRate = controller
              .bestRateHundredthsPercentAt(right)
              .compareTo(controller.bestRateHundredthsPercentAt(left));
          return byRate != 0 ? byRate : left.name.compareTo(right.name);
        });
    }

    return merchants;
  }
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

  /// タイル下に添える補足（還元率順のときだけ渡す）。
  final String Function(MerchantEntry merchant)? rateLabel;

  /// 親のスクロール内に置くときは true。
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: merchants.length,
      itemBuilder: (context, index) {
        final merchant = merchants[index];

        return InkWell(
          onTap: () => onTap(merchant),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              LogoTile(
                assetPath: merchantLogoPath(merchant.id.value),
                label: merchant.name,
                size: 72,
              ),
              const SizedBox(height: 6),
              Text(
                merchant.name,
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

import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../widgets/empty_catalog_notice.dart';
import 'merchant_compare_screen.dart';

/// 店舗一覧。レジ前で店舗を選ぶだけで比較結果に進む（D-088）。
///
/// 金額の入力欄は置かない。並び順はカタログのカテゴリ順で、得意店舗の
/// ない受け皿は最後に置く。
final class MerchantListScreen extends StatefulWidget {
  const MerchantListScreen({super.key});

  @override
  State<MerchantListScreen> createState() => _MerchantListScreenState();
}

final class _MerchantListScreenState extends State<MerchantListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RankingController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('店舗を選ぶ')),
      body: controller.isCatalogEmpty
          ? const EmptyCatalogNotice()
          : _buildBody(context, controller, theme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    RankingController controller,
    ThemeData theme,
  ) {
    final directory = controller.directory;

    if (directory.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('店舗がまだ登録されていません。'),
      );
    }

    final matches = directory.search(_query);
    final categories = _query.trim().isEmpty
        ? directory.orderedCategories
        : <MerchantCategory>[];

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: '店舗を検索',
              hintText: '例: セブン',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('該当する店舗がありません。'),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                  children: <Widget>[
                    if (categories.isEmpty)
                      for (final merchant in matches)
                        _buildTile(context, merchant)
                    else
                      for (final category in categories) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            category.name,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        for (final merchant
                            in directory.merchantsInCategory(category.id))
                          _buildTile(context, merchant),
                      ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTile(BuildContext context, MerchantEntry merchant) {
    return ListTile(
      leading: const Icon(Icons.storefront),
      title: Text(merchant.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.read<RankingController>().compareAtMerchant(merchant);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MerchantCompareScreen(merchant: merchant),
          ),
        );
      },
    );
  }
}

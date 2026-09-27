import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../widgets/empty_catalog_notice.dart';
import '../widgets/logo_tile.dart';
import 'merchant_category_screen.dart';
import 'merchant_compare_screen.dart';

/// 店舗タブ。カテゴリごとに最大4店舗を正方形ロゴで並べる（D-093）。
///
/// カテゴリ名をタップすると、そのカテゴリだけの店舗一覧に移動する。
/// 「得意店舗なし」のような受け皿カテゴリは置かない（D-094）。
final class MerchantListScreen extends StatefulWidget {
  const MerchantListScreen({super.key});

  /// タブ内で見せる1カテゴリあたりの店舗数。
  static const int previewLimit = 4;

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

    return Scaffold(
      appBar: AppBar(title: const Text('店舗を選ぶ')),
      body: controller.isCatalogEmpty
          ? EmptyCatalogNotice(missingFiles: controller.missingCatalogFiles)
          : _buildBody(context, controller),
    );
  }

  Widget _buildBody(BuildContext context, RankingController controller) {
    final directory = controller.directory;

    if (directory.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('店舗がまだ登録されていません。'),
      );
    }

    final searching = _query.trim().isNotEmpty;
    final matches = directory.search(_query);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
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
        if (searching)
          _buildSearchResults(context, directory, matches)
        else
          for (final category in directory.orderedCategories)
            _buildCategorySection(context, controller, directory, category),
      ],
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    MerchantDirectory directory,
    List<MerchantEntry> matches,
  ) {
    if (matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('該当する店舗がありません。'),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MerchantLogoGrid(
        merchants: matches,
        shrinkWrap: true,
        onTap: (merchant) => _open(context, merchant),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    RankingController controller,
    MerchantDirectory directory,
    MerchantCategory category,
  ) {
    final theme = Theme.of(context);
    final all = directory.merchantsInCategory(category.id);
    if (all.isEmpty) {
      return const SizedBox.shrink();
    }

    final preview = all.take(MerchantListScreen.previewLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: () => _openCategory(context, category),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(category.name, style: theme.textTheme.titleMedium),
                ),
                Text(
                  all.length > preview.length
                      ? 'すべて見る（${all.length}店）'
                      : '${all.length}店',
                  style: theme.textTheme.bodySmall,
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
        MerchantLogoGrid(
          merchants: preview,
          shrinkWrap: true,
          onTap: (merchant) => _open(context, merchant),
        ),
      ],
    );
  }

  void _open(BuildContext context, MerchantEntry merchant) {
    context.read<RankingController>().compareAtMerchant(merchant);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MerchantCompareScreen(merchant: merchant),
      ),
    );
  }

  void _openCategory(BuildContext context, MerchantCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MerchantCategoryScreen(category: category),
      ),
    );
  }
}

import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';

/// カテゴリそのものの並び順を入れ替える画面（D-095）。
///
/// 指でつまんで上下に動かすだけで並べ替えられる。並び順は端末に保存され、
/// 次にアプリを開いたときも同じ順で表示される。
final class CategoryOrderScreen extends StatefulWidget {
  const CategoryOrderScreen({super.key});

  @override
  State<CategoryOrderScreen> createState() => _CategoryOrderScreenState();
}

final class _CategoryOrderScreenState extends State<CategoryOrderScreen> {
  late List<MerchantCategory> _categories;

  @override
  void initState() {
    super.initState();
    _categories = context.read<RankingController>().orderedCategories.toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('カテゴリの並べ替え'),
        actions: <Widget>[
          TextButton(
            onPressed: () => _save(context),
            child: const Text('保存'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'つまんで上下に動かすと順番が変わります。終わったら「保存」を押してください。',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: _categories.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('カテゴリがまだありません。'),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                    itemCount: _categories.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final moved = _categories.removeAt(oldIndex);
                        _categories.insert(newIndex, moved);
                      });
                    },
                    itemBuilder: (context, index) {
                      final category = _categories[index];

                      return Card(
                        key: ValueKey<String>(category.id.value),
                        child: ListTile(
                          leading: const Icon(Icons.drag_handle),
                          title: Text(category.name),
                          subtitle: Text('${index + 1}番目'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final controller = context.read<RankingController>();
    final messenger = ScaffoldMessenger.of(context);

    await controller.saveCategoryOrder(_categories);
    messenger.showSnackBar(
      const SnackBar(content: Text('カテゴリの並び順を保存しました。')),
    );

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

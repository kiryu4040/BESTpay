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
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _categories = context.read<RankingController>().orderedCategories.toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarForeground =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        final leave = await _confirmLeave(context);
        if (leave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('カテゴリの並べ替え'),
          actions: <Widget>[
            TextButton(
              onPressed: () => _save(context),
              style: TextButton.styleFrom(foregroundColor: appBarForeground),
              child: const Text('保存'),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '左のつまみを触ったまま上下に動かすと順番が変わります。'
                '終わったら「保存」を押してください。',
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
                      buildDefaultDragHandles: false,
                      itemCount: _categories.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final moved = _categories.removeAt(oldIndex);
                          _categories.insert(newIndex, moved);
                          _isDirty = true;
                        });
                      },
                      itemBuilder: (context, index) {
                        final category = _categories[index];

                        return Card(
                          key: ValueKey<String>(category.id.value),
                          child: ListTile(
                            leading: ReorderableDragStartListener(
                              index: index,
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(Icons.drag_handle, size: 30),
                              ),
                            ),
                            title: Text(category.name),
                            subtitle: Text('${index + 1}番目'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 保存せずに戻ろうとしたときの確認（D-161）。
  Future<bool> _confirmLeave(BuildContext context) async {
    if (!_isDirty) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('並び順を保存しますか？'),
        content: const Text(
          '並べ替えた内容がまだ保存されていません。'
          '保存して戻るか、変更を破棄して戻るかを選んでください。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('このまま戻る'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('編集を続ける'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('保存して戻る'),
          ),
        ],
      ),
    );

    if (result == null) {
      return false;
    }
    if (result && context.mounted) {
      await _save(context, pop: false);
    }

    return true;
  }

  Future<void> _save(BuildContext context, {bool pop = true}) async {
    final controller = context.read<RankingController>();
    final messenger = ScaffoldMessenger.of(context);

    await controller.saveCategoryOrder(_categories);
    _isDirty = false;
    messenger.showSnackBar(
      const SnackBar(content: Text('カテゴリの並び順を保存しました。')),
    );

    if (pop && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

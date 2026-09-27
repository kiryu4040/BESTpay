import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../widgets/logo_tile.dart';

/// カテゴリ内の店舗の並び順を入れ替える画面（D-099）。
///
/// 操作はカテゴリの並べ替えと同じ。つまみを触った瞬間から動かせる。
final class MerchantOrderScreen extends StatefulWidget {
  const MerchantOrderScreen({super.key, required this.category});

  final MerchantCategory category;

  @override
  State<MerchantOrderScreen> createState() => _MerchantOrderScreenState();
}

final class _MerchantOrderScreenState extends State<MerchantOrderScreen> {
  late List<MerchantEntry> _merchants;

  @override
  void initState() {
    super.initState();
    _merchants = context
        .read<RankingController>()
        .merchantsInCategoryOrdered(widget.category.id)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category.name}の並べ替え'),
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
              '左のつまみを触ったまま上下に動かすと順番が変わります。'
              '終わったら「保存」を押してください。',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: _merchants.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('このカテゴリの店舗はまだありません。'),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                    buildDefaultDragHandles: false,
                    itemCount: _merchants.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final moved = _merchants.removeAt(oldIndex);
                        _merchants.insert(newIndex, moved);
                      });
                    },
                    itemBuilder: (context, index) {
                      final merchant = _merchants[index];

                      return Card(
                        key: ValueKey<String>(merchant.id.value),
                        child: ListTile(
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(Icons.drag_handle, size: 30),
                            ),
                          ),
                          title: Text(merchant.name),
                          subtitle: Text('${index + 1}番目'),
                          trailing: LogoTile(
                            assetPath: merchantLogoPath(merchant.id.value),
                            label: merchant.name,
                            size: 40,
                            padding: 3,
                          ),
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

    await controller.saveMerchantOrder(widget.category.id, _merchants);
    messenger.showSnackBar(
      const SnackBar(content: Text('店舗の並び順を保存しました。')),
    );

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

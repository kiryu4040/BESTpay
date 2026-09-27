import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:flutter/material.dart';

import 'entity_avatar.dart';

/// ロゴを正方形で規則正しく並べるグリッド（D-094）。
///
/// 1行の件数を固定し、各セルは正方形。並べ替えモードでは上下ボタンを出す。
final class EntityLogoGrid extends StatelessWidget {
  const EntityLogoGrid({
    super.key,
    required this.merchants,
    required this.onTap,
    this.columns = 4,
    this.reordering = false,
    this.onMoveUp,
    this.onMoveDown,
  });

  final List<MerchantEntry> merchants;
  final void Function(MerchantEntry merchant) onTap;

  /// 1行に並べる件数。正方形を保つ。
  final int columns;

  /// 並べ替えモード。true のとき上下ボタンを表示する。
  final bool reordering;

  final void Function(int index)? onMoveUp;
  final void Function(int index)? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: reordering ? 0.62 : 0.82,
      ),
      itemCount: merchants.length,
      itemBuilder: (context, index) {
        final merchant = merchants[index];

        return _Cell(
          merchant: merchant,
          onTap: () => onTap(merchant),
          reordering: reordering,
          canMoveUp: index > 0,
          canMoveDown: index < merchants.length - 1,
          onMoveUp: onMoveUp == null ? null : () => onMoveUp!(index),
          onMoveDown: onMoveDown == null ? null : () => onMoveDown!(index),
        );
      },
    );
  }
}

final class _Cell extends StatelessWidget {
  const _Cell({
    required this.merchant,
    required this.onTap,
    required this.reordering,
    required this.canMoveUp,
    required this.canMoveDown,
    this.onMoveUp,
    this.onMoveDown,
  });

  final MerchantEntry merchant;
  final VoidCallback onTap;
  final bool reordering;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: reordering ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: EntityAvatar(
            id: merchant.id.value,
            name: merchant.name,
            imageFolder: 'merchants',
            size: 60,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          merchant.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        if (reordering)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: '上へ',
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: '下へ',
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
            ],
          ),
      ],
    );
  }
}

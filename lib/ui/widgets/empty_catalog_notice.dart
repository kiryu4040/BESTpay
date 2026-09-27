import 'package:flutter/material.dart';

/// カタログが空のときに表示する共通の案内カード。
///
/// v2 フェーズ1ではカード実データを同梱していないため、
/// この案内が各画面に表示されるのが正常な状態。
final class EmptyCatalogNotice extends StatelessWidget {
  const EmptyCatalogNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.inbox_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'カタログはまだ空です',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '保有カードのデータがまだ登録されていません。\n'
              'カードの追加手順はリポジトリ内の\n'
              'docs/decisions/card_addition_runbook.md を参照してください。',
            ),
          ],
        ),
      ),
    );
  }
}

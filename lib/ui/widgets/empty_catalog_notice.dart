import 'package:flutter/material.dart';

/// カタログが空のときに出す案内。
///
/// 空の理由（読み込めなかったファイル名）が分かる場合は併記する。
/// 「なぜか空」で止まると原因を追えないため。
final class EmptyCatalogNotice extends StatelessWidget {
  const EmptyCatalogNotice({super.key, this.missingFiles = const <String>[]});

  /// 読み込めなかったカタログファイル名。
  final List<String> missingFiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('カタログはまだ空です'),
            if (missingFiles.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('読み込めなかったファイル:', style: theme.textTheme.titleSmall),
              for (final fileName in missingFiles)
                Text('・$fileName', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(
                'アプリに入っているカタログのファイルが見つからないか、'
                '内容を読み取れませんでした。',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

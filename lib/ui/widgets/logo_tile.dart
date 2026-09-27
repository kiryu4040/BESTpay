import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 正方形のロゴタイル。店舗・カードの見た目を1か所にまとめる（D-092）。
///
/// 画像は `rootBundle` から自分で読み、読み込めない場合は名前の先頭2文字を
/// ブランド色の正方形に描いて代用する。`Image.asset` を使わないのは、
/// 画像が無いときに例外が記録されて画面が赤いエラー表示になり得るため。
/// 画像を後から差し替えても、そのまま反映される。
final class LogoTile extends StatefulWidget {
  const LogoTile({
    super.key,
    required this.assetPath,
    required this.label,
    this.size = 64,
    this.padding = 6,
  });

  /// 例: `assets/images/merchants/seven_eleven.png`
  final String assetPath;

  /// 画像が無いときに表示する文字（名前から作る）。
  final String label;

  final double size;
  final double padding;

  /// 同じ画像を何度も読み直さないようにする。
  static final Map<String, Future<Uint8List?>> _cache =
      <String, Future<Uint8List?>>{};

  static Future<Uint8List?> _bytesFor(String path) {
    return _cache.putIfAbsent(path, () => _loadBytes(path));
  }

  static Future<Uint8List?> _loadBytes(String path) async {
    try {
      final data = await rootBundle.load(path);

      return data.buffer.asUint8List();
    } on Object {
      return null;
    }
  }

  @override
  State<LogoTile> createState() => _LogoTileState();
}

final class _LogoTileState extends State<LogoTile> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = LogoTile._bytesFor(widget.assetPath);
  }

  @override
  void didUpdateWidget(LogoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 並べ替えで別の店舗・カードがこの位置に来たときに取り違えないよう、
    // パスが変わったら読み込み直す（D-098）。
    if (oldWidget.assetPath != widget.assetPath) {
      _bytes = LogoTile._bytesFor(widget.assetPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(widget.size * 0.22);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(widget.padding),
        child: FutureBuilder<Uint8List?>(
          future: _bytes,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data != null && data.isNotEmpty) {
              return Image.memory(
                data,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              );
            }

            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }

            return _buildFallback(theme);
          },
        ),
      ),
    );
  }

  Widget _buildFallback(ThemeData theme) {
    final palette = <Color>[
      const Color(0xFF0B6E4F),
      const Color(0xFF12507B),
      const Color(0xFF8C1D18),
      const Color(0xFF7A4E00),
      const Color(0xFF4A2C82),
      const Color(0xFF00566B),
    ];
    final color = palette[widget.label.hashCode.abs() % palette.length];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(widget.size * 0.18),
      ),
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              _initialsOf(widget.label),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: widget.size * 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 名前の先頭2文字（サロゲートを壊さない）。
String _initialsOf(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) {
    return '?';
  }

  return String.fromCharCodes(trimmed.runes.take(2));
}

/// 店舗ロゴのアセットパス（命名規則は D-092）。
String merchantLogoPath(String merchantId) =>
    'assets/images/merchants/$merchantId.png';

/// カード券面のアセットパス（命名規則は D-092）。
String cardLogoPath(String instrumentId) =>
    'assets/images/cards/$instrumentId.png';

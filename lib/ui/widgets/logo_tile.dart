import 'package:flutter/material.dart';

/// 正方形のロゴタイル。店舗・カードの見た目を1か所にまとめる（D-092）。
///
/// 画像が用意されていない場合は、名前の先頭2文字をブランド色の正方形に
/// 描いて代用する。画像の有無で画面の形が崩れないことを優先する。
final class LogoTile extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(size * 0.22);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => _buildFallback(theme),
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
    final color = palette[label.hashCode.abs() % palette.length];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              LogoTile.initialsOf(label),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 名前の先頭2文字（サロゲートを壊さない）。
  static String initialsOf(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return '?';
    }

    return String.fromCharCodes(trimmed.runes.take(2));
  }
}

/// 店舗ロゴのアセットパス（命名規則は D-092）。
String merchantLogoPath(String merchantId) =>
    'assets/images/merchants/$merchantId.png';

/// カード券面のアセットパス（命名規則は D-092）。
String cardLogoPath(String instrumentId) =>
    'assets/images/cards/$instrumentId.png';

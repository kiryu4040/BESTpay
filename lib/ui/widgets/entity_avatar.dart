import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// カード・店舗のロゴを正方形で表示する。
///
/// `assets/images/<folder>/<id>.png` があればその画像を、
/// 無ければIDから決まる色と頭文字の代替ロゴを表示する。
/// 画像を追加するだけで表示が切り替わる（pubspec の変更は不要）。
final class EntityAvatar extends StatelessWidget {
  const EntityAvatar({
    super.key,
    required this.id,
    required this.name,
    required this.imageFolder,
    this.size = 72,
  });

  /// カタログのID。画像ファイル名にも使う。
  final String id;

  /// 代替ロゴに使う頭文字の元。
  final String name;

  /// `cards` または `merchants`。
  final String imageFolder;

  /// 正方形の一辺（論理ピクセル）。
  final double size;

  /// 画像の場所。存在しなければ代替ロゴになる。
  String get assetPath => 'assets/images/$imageFolder/$id.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _fallback(context),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final color = _colorFor(id);

    return ColoredBox(
      color: color,
      child: Center(
        child: Text(
          _initial(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 名前の先頭1文字。英字なら大文字にする。
  static String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '?';
    }

    return trimmed.characters.first.toUpperCase();
  }

  /// IDから決まる色。同じIDなら常に同じ色になる。
  static Color _colorFor(String id) {
    var hash = 0;
    for (final code in id.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }

    const palette = <Color>[
      Color(0xFF1E88E5),
      Color(0xFF43A047),
      Color(0xFFE53935),
      Color(0xFF8E24AA),
      Color(0xFFF4511E),
      Color(0xFF00897B),
      Color(0xFF3949AB),
      Color(0xFF6D4C41),
    ];

    return palette[hash % palette.length];
  }
}

/// 画像が実在するかを確かめずに `Image.asset` へ渡すための補助。
///
/// Flutter の `errorBuilder` が代替表示を担うため、事前確認は不要。
/// この関数は将来の事前チェック用に残している。
@Deprecated('Use Image.asset errorBuilder instead.')
Future<bool> assetImageExists(String path) async {
  if (kIsWeb) {
    return false;
  }

  return File(path).exists();
}

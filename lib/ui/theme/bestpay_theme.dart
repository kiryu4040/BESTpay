import 'package:flutter/material.dart';

/// クール系の配色（D-121）。
///
/// 白一色だと味気ないため、青みがかった濃淡でまとめる。色はすべて
/// この1ファイルに集約し、画面側では色を直書きしない。
final class BestPayTheme {
  const BestPayTheme._();

  /// 基準になる青。深すぎず、クールに見える青。
  static const Color seed = Color(0xFF2F4B7C);

  /// 背景。わずかに青みを残したオフホワイト。
  static const Color background = Color(0xFFF1F4FA);

  /// 面（カード）の色。
  static const Color surface = Color(0xFFFFFFFF);

  /// 面の境界線。
  static const Color outline = Color(0xFFD7DEEA);

  /// 強調（最有力カードなど）。
  static const Color accentContainer = Color(0xFFE3EBFA);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // 日本語の標準字体を最優先にする（簡体字グリフへの落下を防ぐ・D-120）。
      fontFamilyFallback: const <String>[
        'Noto Sans JP',
        'Noto Sans CJK JP',
        'Yu Gothic',
        'Hiragino Sans',
      ],
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
              fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accentContainer,
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: outline),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: const DividerThemeData(color: outline, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accentContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: seed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}

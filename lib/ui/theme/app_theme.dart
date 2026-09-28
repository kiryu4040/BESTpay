import 'package:flutter/material.dart';

/// BESTpay の配色（D-120）。
///
/// 白一色だと味気ないため、青緑寄りの寒色でまとめる。
/// 背景はわずかに青みを持たせ、カード面は白、強調は深い青緑。
final class AppTheme {
  const AppTheme._();

  /// 寒色の基調色（深い青緑）。
  static const Color seed = Color(0xFF1F4E5F);

  /// 濃い面（アプリバー・結論カード）に使う色。
  static const Color deep = Color(0xFF16323C);

  /// 差し色（くすんだ水色）。
  static const Color accent = Color(0xFF2E7D8F);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: seed,
      onPrimary: Colors.white,
      secondary: accent,
      surface: Colors.white,
      surfaceContainerHighest: const Color(0xFFE3EDF1),
      outlineVariant: const Color(0xFFC7D8DF),
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF1F5F7),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: deep,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: scheme.surfaceContainerHighest,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => base.textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected) ? seed : scheme.outline,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? seed
                : scheme.outline,
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: seed,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? seed : null,
        ),
      ),
    );
  }
}

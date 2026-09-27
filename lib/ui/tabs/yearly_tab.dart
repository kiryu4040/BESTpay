import 'package:flutter/material.dart';

/// 年間タブ（骨格）。
///
/// 金額の入力はここだけで扱う（店舗タブでは入力させない・D-088）。
/// 次フェーズで、年間の利用額から還元額の集計を実装する。
final class YearlyTab extends StatelessWidget {
  const YearlyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('年間')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '年間の利用額の入力と、年間の還元サマリーはここに実装予定です。\n'
            '（店舗タブでは金額を入力しません）',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

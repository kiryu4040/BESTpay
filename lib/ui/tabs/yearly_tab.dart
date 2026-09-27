import 'package:flutter/material.dart';

/// 年間タブ（骨格）。
///
/// 次フェーズで、年間の利用額・還元額の集計ビューをここに実装する。
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
            '年間の利用・還元サマリーはここに実装予定です。',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

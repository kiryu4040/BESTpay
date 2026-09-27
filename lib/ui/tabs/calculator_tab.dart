import 'package:flutter/material.dart';

/// 電卓タブ（骨格）。
///
/// 次フェーズで、単発の還元率・還元額の試算をここに実装する。
final class CalculatorTab extends StatelessWidget {
  const CalculatorTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('電卓')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '還元額の試算はここに実装予定です。\n'
            'まずは「店舗」タブのランキングをお使いください。',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

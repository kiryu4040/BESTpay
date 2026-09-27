import 'package:flutter/material.dart';

import '../screens/store_ranking_screen.dart';

/// 店舗タブ。「店舗×金額 → 還元額ランキング」画面をそのまま表示する。
final class StoresTab extends StatelessWidget {
  const StoresTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const StoreRankingScreen();
  }
}

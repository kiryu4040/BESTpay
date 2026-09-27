import 'package:flutter/material.dart';

import '../screens/merchant_list_screen.dart';

/// 店舗タブ。レジ前で店舗を選ぶと、その場で最も得なカードが出る（D-088）。
final class StoresTab extends StatelessWidget {
  const StoresTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const MerchantListScreen();
  }
}

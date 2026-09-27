import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'domain/catalog/card_catalog.dart';
import 'infrastructure/catalog/asset_card_catalog_loader.dart';
import 'ui/app_shell.dart';

void main() {
  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => AppState()..loadCatalog(),
      child: const BestPayApp(),
    ),
  );
}

/// アプリ全体の最小状態。
///
/// 現フェーズのカタログは空（カード0枚）が正常系。
/// 空でも起動・表示ができることが v2 の設計要件。
final class AppState extends ChangeNotifier {
  CardCatalog _catalog = CardCatalog.empty();

  CardCatalog get catalog => _catalog;

  /// カタログを読み込む。
  ///
  /// assets/data/cards.json が存在しない・壊れている場合も
  /// 空カタログにフォールバックするため、例外は外に出ない。
  Future<void> loadCatalog() async {
    _catalog = await const AssetCardCatalogLoader().load();
    notifyListeners();
  }
}

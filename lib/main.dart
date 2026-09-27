import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'application/catalog/catalog_repository.dart';
import 'domain/catalog/card_catalog.dart';
import 'infrastructure/catalog/asset_card_catalog_loader.dart';
import 'infrastructure/catalog/asset_catalog_repository.dart';
import 'ui/app_shell.dart';
import 'ui/ranking_controller.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<CatalogRepository>(
          create: (_) => const AssetCatalogRepository(),
        ),
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState()..loadCatalog(),
        ),
        ChangeNotifierProvider<RankingController>(
          create: (context) => RankingController(
            repository: context.read<CatalogRepository>(),
          )..loadCatalog(),
        ),
      ],
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

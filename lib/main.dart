import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'application/catalog/catalog_repository.dart';
import 'infrastructure/catalog/asset_catalog_repository.dart';
import 'ui/app_shell.dart';
import 'ui/ranking_controller.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<CatalogRepository>(
          create: (_) => AssetCatalogRepository(),
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

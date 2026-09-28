import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'application/catalog/catalog_repository.dart';
import 'infrastructure/catalog/asset_catalog_repository.dart';
import 'ui/app_shell.dart';
import 'ui/ranking_controller.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
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

/// BESTpay v2 のルートウィジェット。
///
/// 日本語の字形を標準のものにするため、同梱フォント（Noto Sans JP）と
/// 日本語ロケールを明示する（D-120）。
final class BestPayApp extends StatelessWidget {
  const BestPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BESTpay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ja'),
      supportedLocales: const <Locale>[
        Locale('ja'),
        Locale('en'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(),
    );
  }
}

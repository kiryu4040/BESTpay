import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/bestpay_theme.dart';
import 'tabs/calculator_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/stores_tab.dart';
import 'tabs/yearly_tab.dart';

/// BESTpay v2 のルートウィジェット。
final class BestPayApp extends StatelessWidget {
  const BestPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BESTpay',
      theme: BestPayTheme.light(),
      // 日本語の標準字体を使うため、ロケールを明示する（D-120）。
      locale: const Locale('ja', 'JP'),
      supportedLocales: const <Locale>[Locale('ja', 'JP')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
    );
  }
}

/// ボトムナビ4タブの骨格（D-117でホームを削除）。
/// 店舗 / 計算 / 年間 / 設定
final class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

final class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<Widget> _tabs = <Widget>[
    StoresTab(),
    CalculatorTab(),
    YearlyTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() {
            _index = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: '店舗',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: '計算',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: '年間',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}

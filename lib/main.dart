import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BestPayApp());
}

class BestPayApp extends StatelessWidget {
  const BestPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'BestPay',
            debugShowCheckedModeBanner: false,
            themeMode: state.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1976D2),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              cardTheme: const CardTheme(elevation: 1.5),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF64B5F6),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              cardTheme: const CardTheme(elevation: 1.5),
            ),
            home: state.ready
                ? const HomeScreen()
                : const Scaffold(
                    body: Center(child: CircularProgressIndicator())),
          );
        },
      ),
    );
  }
}

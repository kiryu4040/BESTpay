import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/payment_method.dart';
import '../models/reward_rule.dart';
import '../models/store.dart';

class AppState extends ChangeNotifier {
  AppState() {
    _init();
  }

  final db = DatabaseHelper.instance;

  List<PaymentMethod> payments = [];
  List<Store> favorites = [];
  Map<String, String> conditions = {};
  ThemeMode themeMode = ThemeMode.system;

  bool ready = false;

  Future<void> _init() async {
    await refresh();
    final sp = await SharedPreferences.getInstance();
    final t = sp.getString('themeMode') ?? 'system';
    themeMode = _themeFromString(t);
    ready = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    payments = await db.getPaymentMethods();
    favorites = await db.getStores(favorite: true);
    conditions = await db.getConditions();
    notifyListeners();
  }

  Future<void> togglePayment(int id, bool enabled) async {
    await db.updatePaymentEnabled(id, enabled);
    await refresh();
  }

  Future<void> toggleFavorite(int storeId, bool fav) async {
    await db.toggleFavorite(storeId, fav);
    favorites = await db.getStores(favorite: true);
    notifyListeners();
  }

  Future<void> setCondition(String key, String value) async {
    await db.setCondition(key, value);
    conditions = await db.getConditions();
    notifyListeners();
  }

  Future<void> setConditions(Map<String, String> m) async {
    await db.setConditions(m);
    conditions = await db.getConditions();
    notifyListeners();
  }

  Future<List<RewardRule>> rulesFor(int storeId) =>
      db.getRulesForStore(storeId);

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('themeMode', _themeToString(mode));
    notifyListeners();
  }

  ThemeMode _themeFromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

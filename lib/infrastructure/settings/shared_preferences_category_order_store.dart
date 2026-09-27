import 'package:bestpay/application/settings/category_order_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端末の保存領域にカテゴリの並び順を覚えておく（D-57, D-095）。
///
/// 読み書きに失敗しても例外を出さず、空の並び順を返して画面を止めない。
final class SharedPreferencesCategoryOrderStore implements CategoryOrderStore {
  const SharedPreferencesCategoryOrderStore();

  static const String _key = 'merchant_category_order_v1';

  @override
  Future<List<String>> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();

      return preferences.getStringList(_key) ?? const <String>[];
    } on Object {
      return const <String>[];
    }
  }

  @override
  Future<void> save(List<String> categoryIds) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_key, categoryIds);
    } on Object {
      // 保存できなくても操作は続けられる。
    }
  }
}

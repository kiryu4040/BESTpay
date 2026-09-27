import 'package:bestpay/application/preferences/preference_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences に並べ替え順を保存する（D-57）。
///
/// 保存に失敗しても例外にしない。並べ替えが保存できなくても、その場の
/// 並びだけは反映される（アプリの動作を止めない）。
final class SharedPreferencesStore implements PreferenceStore {
  const SharedPreferencesStore();

  @override
  Future<List<String>> readStringList(String key) async {
    try {
      final preferences = await SharedPreferences.getInstance();

      return preferences.getStringList(key) ?? const <String>[];
    } on Object {
      return const <String>[];
    }
  }

  @override
  Future<void> writeStringList(String key, List<String> value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(key, value);
    } on Object {
      // 保存できなくても画面の並びは保つ。
    }
  }
}

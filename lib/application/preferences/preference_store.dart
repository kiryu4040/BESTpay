/// 利用者の並べ替え順を保存する口（D-57: SharedPreferences）。
///
/// 画面はこの契約だけを知り、保存の実装（SharedPreferences）には依存しない。
abstract interface class PreferenceStore {
  /// 文字列の配列を読む。未保存なら空の配列を返す。
  Future<List<String>> readStringList(String key);

  /// 文字列の配列を保存する。
  Future<void> writeStringList(String key, List<String> value);
}

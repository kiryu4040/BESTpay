import 'package:bestpay/application/preferences/preference_store.dart';

/// テストと、保存が使えない環境向けのメモリ内実装。
final class MemoryPreferenceStore implements PreferenceStore {
  MemoryPreferenceStore([Map<String, List<String>>? seed])
      : _values = <String, List<String>>{...?seed};

  final Map<String, List<String>> _values;

  @override
  Future<List<String>> readStringList(String key) async {
    return List<String>.unmodifiable(_values[key] ?? const <String>[]);
  }

  @override
  Future<void> writeStringList(String key, List<String> value) async {
    _values[key] = List<String>.of(value);
  }
}

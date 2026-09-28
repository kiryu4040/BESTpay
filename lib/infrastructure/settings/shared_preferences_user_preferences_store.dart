import 'package:bestpay/application/settings/user_preferences.dart';
import 'package:bestpay/application/settings/user_preferences_store.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端末の保存領域に利用者設定を覚えておく（D-100）。
///
/// 壊れた値や読み取り失敗はすべて既定値に落とし、起動を止めない。
final class SharedPreferencesUserPreferencesStore
    implements UserPreferencesStore {
  const SharedPreferencesUserPreferencesStore();

  static const String _hiddenCardsKey = 'hidden_card_ids_v1';
  static const String _conditionPrefix = 'condition_state_v2_';
  static const String _conditionCountPrefix = 'condition_count_v1_';
  static const String _categoryOrderKey = 'merchant_category_order_v2';
  static const String _merchantOrderPrefix = 'merchant_order_v2_';

  @override
  Future<UserPreferences> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final conditionStates = <String, TriState>{};
      final conditionCounts = <String, int>{};

      for (final key in preferences.getKeys()) {
        if (key.startsWith(_conditionPrefix)) {
          final state = _stateOf(preferences.getString(key));
          if (state != null) {
            conditionStates[key.substring(_conditionPrefix.length)] = state;
          }
        } else if (key.startsWith(_conditionCountPrefix)) {
          final value = preferences.getInt(key);
          if (value != null) {
            conditionCounts[key.substring(_conditionCountPrefix.length)] = value;
          }
        }
      }

      final merchantOrder = <String, List<String>>{};
      for (final key in preferences.getKeys()) {
        if (!key.startsWith(_merchantOrderPrefix)) {
          continue;
        }

        final value = preferences.getStringList(key);
        if (value != null) {
          merchantOrder[key.substring(_merchantOrderPrefix.length)] = value;
        }
      }

      return UserPreferences(
        hiddenCardIds:
            (preferences.getStringList(_hiddenCardsKey) ?? const <String>[])
                .toSet(),
        conditionStates: conditionStates,
        conditionCounts: conditionCounts,
        categoryOrder:
            preferences.getStringList(_categoryOrderKey) ?? const <String>[],
        merchantOrder: merchantOrder,
      );
    } on Object {
      return const UserPreferences();
    }
  }

  @override
  Future<void> save(UserPreferences preferences) async {
    try {
      final store = await SharedPreferences.getInstance();

      await store.setStringList(
        _hiddenCardsKey,
        preferences.hiddenCardIds.toList(),
      );
      await store.setStringList(_categoryOrderKey, preferences.categoryOrder);

      for (final entry in preferences.conditionStates.entries) {
        await store.setString(
          '$_conditionPrefix${entry.key}',
          entry.value.name,
        );
      }

      for (final entry in preferences.conditionCounts.entries) {
        await store.setInt('$_conditionCountPrefix${entry.key}', entry.value);
      }

      for (final entry in preferences.merchantOrder.entries) {
        await store.setStringList(
          '$_merchantOrderPrefix${entry.key}',
          entry.value,
        );
      }
    } on Object {
      // 保存できなくても操作は続けられる。
    }
  }

  /// 保存名から状態に戻す。未知の名前は捨てる。
  static TriState? _stateOf(String? name) {
    for (final state in TriState.values) {
      if (state.name == name) {
        return state;
      }
    }

    return null;
  }
}

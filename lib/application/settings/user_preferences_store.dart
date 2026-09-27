import 'package:bestpay/application/settings/user_preferences.dart';

/// 利用者設定の読み書き（D-100）。
///
/// 読み書きに失敗しても画面は動く必要があるため、実装は例外を投げない。
abstract interface class UserPreferencesStore {
  Future<UserPreferences> load();

  Future<void> save(UserPreferences preferences);
}

/// 端末に保存しない（テストと保存失敗時の受け皿）。
final class InMemoryUserPreferencesStore implements UserPreferencesStore {
  InMemoryUserPreferencesStore([this._preferences = const UserPreferences()]);

  UserPreferences _preferences;

  @override
  Future<UserPreferences> load() async => _preferences;

  @override
  Future<void> save(UserPreferences preferences) async {
    _preferences = preferences;
  }
}

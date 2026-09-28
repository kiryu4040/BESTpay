import 'package:bestpay/core/value_objects/tri_state.dart';

/// 利用者がアプリ内で決めた設定（D-100）。
///
/// 端末に保存し、次に開いたときも同じ状態にする。カタログには一切書かない。
final class UserPreferences {
  const UserPreferences({
    this.hiddenCardIds = const <String>{},
    this.conditionStates = const <String, TriState>{},
    this.conditionCounts = const <String, int>{},
    this.categoryOrder = const <String>[],
    this.merchantOrder = const <String, List<String>>{},
  });

  /// ランキングに出さないカード（保有はしたまま）。
  final Set<String> hiddenCardIds;

  /// 条件の達成状態（入切）。未設定ならカタログの既定を使う。
  final Map<String, TriState> conditionStates;

  /// 個数で選ぶ条件の数（例: 特定サービスのカード払いの契約数）。
  final Map<String, int> conditionCounts;

  /// 店舗カテゴリの並び順。
  final List<String> categoryOrder;

  /// カテゴリごとの店舗の並び順。
  final Map<String, List<String>> merchantOrder;

  UserPreferences copyWith({
    Set<String>? hiddenCardIds,
    Map<String, TriState>? conditionStates,
    Map<String, int>? conditionCounts,
    List<String>? categoryOrder,
    Map<String, List<String>>? merchantOrder,
  }) {
    return UserPreferences(
      hiddenCardIds: hiddenCardIds ?? this.hiddenCardIds,
      conditionStates: conditionStates ?? this.conditionStates,
      conditionCounts: conditionCounts ?? this.conditionCounts,
      categoryOrder: categoryOrder ?? this.categoryOrder,
      merchantOrder: merchantOrder ?? this.merchantOrder,
    );
  }
}

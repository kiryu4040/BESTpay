import 'package:bestpay/application/preferences/preference_store.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';

/// 店舗カテゴリと店舗の並べ替えを管理する（D-092）。
///
/// 並び順は保存先にIDの配列として持つ。保存に無い項目は既定順のまま
/// 後ろに続くため、カタログに店舗が増えても並びが壊れない。
final class MerchantOrder {
  const MerchantOrder({required PreferenceStore store}) : _store = store;

  final PreferenceStore _store;

  static const String _categoryKey = 'merchant_category_order';

  /// 店舗の並びはカテゴリごとに独立して保存する。
  static String merchantKey(StableId categoryId) {
    return 'merchant_order_${categoryId.value}';
  }

  Future<List<String>> readCategoryOrder() {
    return _store.readStringList(_categoryKey);
  }

  Future<void> saveCategoryOrder(List<StableId> order) {
    return _store.writeStringList(
      _categoryKey,
      <String>[for (final id in order) id.value],
    );
  }

  Future<List<String>> readMerchantOrder(StableId categoryId) {
    return _store.readStringList(merchantKey(categoryId));
  }

  Future<void> saveMerchantOrder(StableId categoryId, List<StableId> order) {
    return _store.writeStringList(
      merchantKey(categoryId),
      <String>[for (final id in order) id.value],
    );
  }

  /// 保存された並び順を [items] に適用する。
  ///
  /// 保存に無い項目（新しく登録した店舗）は元の順序を保って末尾に置く。
  static List<T> applyOrder<T>(
    List<T> items,
    List<String> savedOrder,
    String Function(T item) idOf,
  ) {
    if (savedOrder.isEmpty || items.length < 2) {
      return List<T>.of(items);
    }

    final position = <String, int>{
      for (var index = 0; index < savedOrder.length; index++)
        savedOrder[index]: index,
    };

    final indexed = <MapEntry<int, T>>[];
    for (var index = 0; index < items.length; index++) {
      final saved = position[idOf(items[index])];
      indexed.add(MapEntry<int, T>(saved ?? savedOrder.length + index, items[index]));
    }

    indexed.sort((left, right) => left.key.compareTo(right.key));

    return <T>[for (final entry in indexed) entry.value];
  }

  /// [items] の [index] を1つ上へ動かした新しい並びを返す。
  static List<T> moveUp<T>(List<T> items, int index) {
    if (index <= 0 || index >= items.length) {
      return List<T>.of(items);
    }

    final moved = List<T>.of(items);
    final item = moved.removeAt(index);
    moved.insert(index - 1, item);

    return moved;
  }

  /// [items] の [index] を1つ下へ動かした新しい並びを返す。
  static List<T> moveDown<T>(List<T> items, int index) {
    if (index < 0 || index >= items.length - 1) {
      return List<T>.of(items);
    }

    final moved = List<T>.of(items);
    final item = moved.removeAt(index);
    moved.insert(index + 1, item);

    return moved;
  }
}

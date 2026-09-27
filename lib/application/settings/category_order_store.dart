/// 店舗カテゴリの並び順を覚えておく口（D-095）。
///
/// 保存に失敗しても画面は動く必要があるため、実装は例外を投げない。
abstract interface class CategoryOrderStore {
  /// 保存済みのカテゴリID順。未保存なら空。
  Future<List<String>> load();

  /// カテゴリID順を保存する。
  Future<void> save(List<String> categoryIds);
}

/// 端末に保存しない（テストや保存失敗時の受け皿）。
final class InMemoryCategoryOrderStore implements CategoryOrderStore {
  List<String> _order = const <String>[];

  @override
  Future<List<String>> load() async => List<String>.unmodifiable(_order);

  @override
  Future<void> save(List<String> categoryIds) async {
    _order = List<String>.unmodifiable(categoryIds);
  }
}

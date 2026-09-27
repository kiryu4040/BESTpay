import 'package:bestpay/core/value_objects/stable_id.dart';

/// カタログに登録された店舗1件。
final class MerchantEntry {
  const MerchantEntry({
    required this.id,
    required this.name,
    required this.groupIds,
    required this.categoryIds,
    required this.notes,
    required this.status,
  });

  final StableId id;
  final String name;
  final List<StableId> groupIds;
  final List<StableId> categoryIds;
  final List<String> notes;
  final String status;
}

/// 店舗カテゴリ（コンビニ・ファストフード等）。
final class MerchantCategory {
  const MerchantCategory({
    required this.id,
    required this.name,
    required this.parentCategoryId,
  });

  final StableId id;
  final String name;
  final StableId? parentCategoryId;
}

/// 画面に出す店舗一覧。レジ前で選ぶだけなので、検索できる最小限の情報を持つ。
final class MerchantDirectory {
  MerchantDirectory({
    required Iterable<MerchantEntry> merchants,
    required Iterable<MerchantCategory> categories,
  })  : merchants = List<MerchantEntry>.unmodifiable(merchants),
        categoriesById = Map<StableId, MerchantCategory>.unmodifiable(
          <StableId, MerchantCategory>{
            for (final category in categories) category.id: category,
          },
        );

  factory MerchantDirectory.empty() {
    return MerchantDirectory(
      merchants: const <MerchantEntry>[],
      categories: const <MerchantCategory>[],
    );
  }

  /// 表示順に並んだ店舗（得意店舗なしの受け皿は最後）。
  final List<MerchantEntry> merchants;

  final Map<StableId, MerchantCategory> categoriesById;

  bool get isEmpty => merchants.isEmpty;

  bool get isNotEmpty => merchants.isNotEmpty;

  /// 名前の部分一致で絞り込む。空文字なら全件を返す。
  List<MerchantEntry> search(String query) {
    final needle = query.trim();
    if (needle.isEmpty) {
      return merchants;
    }

    return <MerchantEntry>[
      for (final merchant in merchants)
        if (merchant.name.contains(needle)) merchant,
    ];
  }

  /// カテゴリの表示順。カタログに無いカテゴリは末尾に回す。
  List<MerchantCategory> get orderedCategories {
    final ordered = <MerchantCategory>[];
    final seen = <StableId>{};

    for (final merchant in merchants) {
      for (final categoryId in merchant.categoryIds) {
        final category = categoriesById[categoryId];
        if (category != null && seen.add(categoryId)) {
          ordered.add(category);
        }
      }
    }

    return List<MerchantCategory>.unmodifiable(ordered);
  }

  /// 指定カテゴリに属する店舗。
  List<MerchantEntry> merchantsInCategory(StableId categoryId) {
    return <MerchantEntry>[
      for (final merchant in merchants)
        if (merchant.categoryIds.contains(categoryId)) merchant,
    ];
  }

  /// 店舗IDで1件引く。
  MerchantEntry? merchantById(StableId merchantId) {
    for (final merchant in merchants) {
      if (merchant.id == merchantId) {
        return merchant;
      }
    }

    return null;
  }
}

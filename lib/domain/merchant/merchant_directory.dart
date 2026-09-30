import 'package:bestpay/core/value_objects/stable_id.dart';

import 'merchant_search_normalizer.dart';

/// カタログに登録された店舗1件。
final class MerchantEntry {
  const MerchantEntry({
    required this.id,
    required this.name,
    required this.groupIds,
    required this.categoryIds,
    required this.notes,
    required this.status,
    this.searchAliases = const <String>[],
  });

  final StableId id;
  final String name;

  /// 検索のときにだけ使う別名（略称・読み方・英字表記）。D-140。
  final List<String> searchAliases;
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

  /// 店舗名と別名を正規化して絞り込む（D-140）。
  ///
  /// ひらがな・カタカナ・半角カナ・全角英数の違いを吸収するので、
  /// 「すたば」でも「ｽﾀﾊﾞ」でも「スターバ」でもスターバックスが出る。
  /// 空文字（記号だけの入力も含む）なら全件を返す。
  List<MerchantEntry> search(String query) {
    final needle = normalizeForSearch(query);
    if (needle.isEmpty) {
      return merchants;
    }

    final hits = <_SearchHit>[];
    for (var index = 0; index < merchants.length; index++) {
      final merchant = merchants[index];
      final score = _matchScore(merchant, needle);
      if (score != null) {
        hits.add(_SearchHit(score: score, index: index, merchant: merchant));
      }
    }

    // 前方一致を先に、同じ順位ならカタログの並び順のまま返す。
    hits.sort((left, right) {
      if (left.score != right.score) {
        return left.score - right.score;
      }
      return left.index - right.index;
    });

    return List<MerchantEntry>.unmodifiable(
      <MerchantEntry>[for (final hit in hits) hit.merchant],
    );
  }

  /// 一致の強さ。小さいほど上位に出す。一致しなければ null。
  static int? _matchScore(MerchantEntry merchant, String needle) {
    final name = normalizeForSearch(merchant.name);
    if (name.startsWith(needle)) {
      return 0;
    }
    if (name.contains(needle)) {
      return 1;
    }

    var best = 4;
    for (final alias in merchant.searchAliases) {
      final normalized = normalizeForSearch(alias);
      if (normalized.isEmpty) {
        continue;
      }
      if (normalized.startsWith(needle)) {
        if (best > 2) {
          best = 2;
        }
        continue;
      }
      if (normalized.contains(needle) && best > 3) {
        best = 3;
      }
    }

    return best == 4 ? null : best;
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

final class _SearchHit {
  const _SearchHit({
    required this.score,
    required this.index,
    required this.merchant,
  });

  final int score;
  final int index;
  final MerchantEntry merchant;
}

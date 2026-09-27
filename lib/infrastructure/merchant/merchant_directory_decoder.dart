import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';

/// `merchants.json` と `merchant_categories.json` を画面用の一覧に変換する。
///
/// 第1期は有効（active）な店舗だけを表示する。壊れたIDの店舗は黙って
/// 落とし、画面には出さない（カタログは信頼できない入力として扱う）。
final class MerchantDirectoryDecoder {
  const MerchantDirectoryDecoder();

  MerchantDirectory decode({
    required Map<String, Object?> merchants,
    required Map<String, Object?> merchantCategories,
  }) {
    final entries = <MerchantEntry>[];

    for (final raw in _items(merchants)) {
      if (raw['status'] != 'active') {
        continue;
      }

      final id = _stableId(raw['id']);
      final name = raw['name'];
      if (id == null || name is! String || name.isEmpty) {
        continue;
      }

      entries.add(
        MerchantEntry(
          id: id,
          name: name,
          groupIds: _stableIds(raw['merchantGroupIds']),
          categoryIds: _stableIds(raw['categoryIds']),
          notes: _strings(raw['notes']),
          status: 'active',
        ),
      );
    }

    entries.sort((left, right) {
      final leftOther = _isFallback(left) ? 1 : 0;
      final rightOther = _isFallback(right) ? 1 : 0;
      if (leftOther != rightOther) {
        return leftOther - rightOther;
      }

      final categoryComparison = _categoryKey(left).compareTo(_categoryKey(right));
      if (categoryComparison != 0) {
        return categoryComparison;
      }

      return left.name.compareTo(right.name);
    });

    final categories = <MerchantCategory>[];
    for (final raw in _items(merchantCategories)) {
      if (raw['status'] != 'active') {
        continue;
      }

      final id = _stableId(raw['id']);
      final name = raw['name'];
      if (id == null || name is! String || name.isEmpty) {
        continue;
      }

      categories.add(
        MerchantCategory(
          id: id,
          name: name,
          parentCategoryId: _stableId(raw['parentCategoryId']),
        ),
      );
    }

    return MerchantDirectory(merchants: entries, categories: categories);
  }

  static bool _isFallback(MerchantEntry merchant) {
    return merchant.categoryIds.any((id) => id.value == 'other_store');
  }

  static String _categoryKey(MerchantEntry merchant) {
    return merchant.categoryIds.isEmpty ? 'zzz' : merchant.categoryIds.first.value;
  }

  static Iterable<Map<String, Object?>> _items(Map<String, Object?> document) {
    final raw = document['items'];
    if (raw is! List) {
      return const <Map<String, Object?>>[];
    }

    return <Map<String, Object?>>[
      for (final item in raw)
        if (item is Map) item.cast<String, Object?>(),
    ];
  }

  static List<String> _strings(Object? raw) {
    if (raw is! List) {
      return const <String>[];
    }

    return <String>[
      for (final item in raw)
        if (item is String && item.isNotEmpty) item,
    ];
  }

  static List<StableId> _stableIds(Object? raw) {
    if (raw is! List) {
      return const <StableId>[];
    }

    final out = <StableId>[];
    for (final item in raw) {
      final id = _stableId(item);
      if (id != null) {
        out.add(id);
      }
    }

    return List<StableId>.unmodifiable(out);
  }

  static StableId? _stableId(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }

    return StableId.create(raw).fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
  }
}

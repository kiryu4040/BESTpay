import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/result/app_result.dart';
import '../../core/value_objects/stable_id.dart';
import '../../domain/catalog/card_catalog.dart';

/// assets/data/cards.json から保有カードカタログを読み込む最小ローダー。
///
/// フェーズ1では assets/data/ をアプリに同梱しないため、
/// 実際には常に空カタログが返る。それが正常動作。
/// ファイルが無い・JSONが壊れている・形式が違う、のいずれでも
/// 例外を投げずに空カタログへフォールバックする（クラッシュさせない）。
///
/// 次フェーズで cards.json を同梱する際は、
/// pubspec.yaml の flutter: セクションに assets 宣言を追加すること。
final class AssetCardCatalogLoader {
  const AssetCardCatalogLoader();

  static const String assetPath = 'assets/data/cards.json';

  Future<CardCatalog> load() async {
    String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (_) {
      // アセット未同梱は現フェーズの正常系。
      return CardCatalog.empty();
    }

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, Object?>) {
        return CardCatalog.empty();
      }

      final cards = decoded['cards'];
      if (cards is! List) {
        return CardCatalog.empty();
      }

      final parsed = <OwnedCard>[];
      for (final entry in cards) {
        if (entry is! Map) {
          continue;
        }
        final id = entry['id'];
        final name = entry['name'];
        if (id is! String || name is! String || name.isEmpty) {
          continue;
        }
        final idResult = StableId.create(id);
        if (idResult is AppSuccess<StableId>) {
          parsed.add(OwnedCard(id: idResult.value, displayName: name));
        }
        // 不正なIDのカードは読み飛ばす（1枚の不正で全体を止めない）。
      }

      return CardCatalog(cards: List<OwnedCard>.unmodifiable(parsed));
    } catch (_) {
      return CardCatalog.empty();
    }
  }
}

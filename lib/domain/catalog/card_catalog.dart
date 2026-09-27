import '../../core/value_objects/stable_id.dart';

/// 保有カード1枚分の最小表現（v2 フェーズ1）。
///
/// 還元ルール（RewardRuleSet）との接続は次フェーズで行う。
/// その際もこの型は壊れないよう、ID と表示名だけを持つ。
final class OwnedCard {
  const OwnedCard({
    required this.id,
    required this.displayName,
  });

  final StableId id;
  final String displayName;
}

/// 保有カードの一覧（カタログ）。
///
/// 「カードが1枚も無い」は異常ではなく初期状態として表現する。
/// 0枚でも全ての呼び出しが安全に動くことが前提。
final class CardCatalog {
  const CardCatalog({required this.cards});

  /// 空カタログ。カタログデータ未整備の初期状態。
  factory CardCatalog.empty() => const CardCatalog(cards: <OwnedCard>[]);

  final List<OwnedCard> cards;

  bool get isEmpty => cards.isEmpty;
  bool get isNotEmpty => cards.isNotEmpty;
}

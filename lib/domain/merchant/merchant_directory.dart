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
    final needle = _normalizeForSearch(query);
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
    final name = _normalizeForSearch(merchant.name);
    if (name.startsWith(needle)) {
      return 0;
    }
    if (name.contains(needle)) {
      return 1;
    }

    var best = 4;
    for (final alias in merchant.searchAliases) {
      final normalized = _normalizeForSearch(alias);
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

/// 検索の一致順位を決めるための作業用の値。
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

// ---------------------------------------------------------------------------
// 店舗検索の文字そろえ（D-140）
//
// レジ前で急いで打つときは「すたば」「ファミマ」「ｽﾀﾊﾞ」「マック」のように
// 表記がばらつく。ここで次の4つを吸収する。
//
// 1. 半角カナ → 全角カナ（濁点・半濁点の組み合わせも解決する）
// 2. 全角英数 → 半角英数（大小文字は区別しない）
// 3. カタカナ → ひらがな
// 4. 区切り記号（空白・中黒・長音・かっこ・ハイフン等）を除去
//
// これにより「スタバ」「すたば」「ｽﾀﾊﾞ」「スターバ」が同じ検索語になる。
// ---------------------------------------------------------------------------

final Map<String, String> _searchTable = _buildSearchTable();

/// 濁点を直前の文字に合成するための対応表。
const Map<String, String> _dakuten = <String, String>{
  'か': 'が', 'き': 'ぎ', 'く': 'ぐ', 'け': 'げ', 'こ': 'ご',
  'さ': 'ざ', 'し': 'じ', 'す': 'ず', 'せ': 'ぜ', 'そ': 'ぞ',
  'た': 'だ', 'ち': 'ぢ', 'つ': 'づ', 'て': 'で', 'と': 'ど',
  'は': 'ば', 'ひ': 'び', 'ふ': 'ぶ', 'へ': 'べ', 'ほ': 'ぼ',
  'う': 'ゔ', 'わ': 'ゔ',
};

/// 半濁点を直前の文字に合成するための対応表。
const Map<String, String> _handakuten = <String, String>{
  'は': 'ぱ', 'ひ': 'ぴ', 'ふ': 'ぷ', 'へ': 'ぺ', 'ほ': 'ぽ',
};

Map<String, String> _buildSearchTable() {
  final table = <String, String>{};

  // 1. 半角カナ → 全角カナ
  const halfKana = '｡｢｣､･ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝﾞﾟ';
  const fullKana = '。「」、・ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン゛゜';
  for (var i = 0; i < halfKana.length && i < fullKana.length; i++) {
    table[halfKana[i]] = fullKana[i];
  }

  // 2. 全角英数 → 半角英数
  for (var i = 0; i < 26; i++) {
    table[String.fromCharCode(0xFF21 + i)] = String.fromCharCode(0x41 + i);
    table[String.fromCharCode(0xFF41 + i)] = String.fromCharCode(0x61 + i);
  }
  for (var i = 0; i < 10; i++) {
    table[String.fromCharCode(0xFF10 + i)] = String.fromCharCode(0x30 + i);
  }

  // 3. カタカナ → ひらがな（長音・中黒はここでは触らない）
  for (var code = 0x30A1; code <= 0x30F6; code++) {
    if (code == 0x30FB || code == 0x30FC) {
      continue;
    }
    table[String.fromCharCode(code)] = String.fromCharCode(code - 0x60);
  }

  // 4. 区切り記号・長音は落とす
  const ignored = ' 　\t・･ー―‐-−ｰ/\\.,，．、（）()「」『』[]【】〔〕'
      '"\'’‘“”〜~:;：；!！?？*＊×+#＃&＆@＠_＿＝=｜|＜＞<>％%';
  for (final char in ignored.split('')) {
    table[char] = '';
  }

  return table;
}

/// 検索用の文字列にそろえる（D-140）。
String _normalizeForSearch(String input) {
  if (input.isEmpty) {
    return '';
  }

  final chars = input.split('');
  final out = StringBuffer();
  var index = 0;

  while (index < chars.length) {
    final char = _normalizeChar(chars[index]);
    final next = index + 1 < chars.length
        ? _normalizeChar(chars[index + 1])
        : '';

    // 「ハ」＋「゛」のように、濁点・半濁点は直前の1文字に合成する。
    if (next == '゛' || next == '゜') {
      final merged = _mergeWithMark(char, next);
      if (merged != null) {
        out.write(merged);
      } else if (!_isMarkChar(char)) {
        out.write(char);
      }
      index += 2;
      continue;
    }

    if (!_isMarkChar(char)) {
      out.write(char);
    }
    index += 1;
  }

  return out.toString().toLowerCase();
}

String? _mergeWithMark(String base, String mark) {
  final normalized = _normalizeChar(base);

  if (mark == '゛') {
    return _dakuten[normalized];
  }

  return _handakuten[normalized];
}

bool _isMarkChar(String char) => char == '゛' || char == '゜';

/// 半角カナは「半角→全角→ひらがな」の2段階で変換する必要がある。
String _normalizeChar(String char) {
  final once = _searchTable[char] ?? char;
  return _searchTable[once] ?? once;
}

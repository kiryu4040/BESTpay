/// 店舗検索の入力語と店舗名をそろえるための正規化（D-140）。
///
/// レジ前で急いで打つときは「すたば」「ファミマ」「ｽﾀﾊﾞ」「マック」のように
/// 表記がばらつく。ここで次の4つを吸収する。
///
/// 1. 半角カナ → 全角カナ（濁点・半濁点の組み合わせも解決する）
/// 2. 全角英数 → 半角英数（大小文字は区別しない）
/// 3. カタカナ → ひらがな
/// 4. 区切り記号（空白・中黒・長音・かっこ・ハイフン等）を除去
///
/// これにより「スタバ」「すたば」「ｽﾀﾊﾞ」「スターバ」が同じ検索語になる。
library;

final Map<String, String> _table = _buildTable();

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

Map<String, String> _buildTable() {
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
String normalizeForSearch(String input) {
  if (input.isEmpty) {
    return '';
  }

  final chars = input.split('');
  final out = StringBuffer();
  var index = 0;

  while (index < chars.length) {
    final char = _normalizeChar(chars[index]);
    final next = index + 1 < chars.length ? _normalizeChar(chars[index + 1]) : '';

    // 「ハ」＋「゛」のように、濁点・半濁点は直前の1文字に合成する。
    if (next == '゛' || next == '゜') {
      final merged = _mergeWith(char, next);
      if (merged != null) {
        out.write(merged);
      } else if (!_isMark(char)) {
        out.write(char);
      }
      index += 2;
      continue;
    }

    if (!_isMark(char)) {
      out.write(char);
    }
    index += 1;
  }

  return out.toString().toLowerCase();
}

String? _mergeWith(String base, String mark) {
  final normalized = _normalizeChar(base);

  if (mark == '゛') {
    return _dakuten[normalized];
  }

  return _handakuten[normalized];
}

bool _isMark(String char) => char == '゛' || char == '゜';

/// 半角カナは「半角→全角→ひらがな」の2段階で変換する必要がある。
String _normalizeChar(String char) {
  final once = _table[char] ?? char;
  return _table[once] ?? once;
}

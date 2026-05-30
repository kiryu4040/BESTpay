import 'package:sqflite/sqflite.dart';

/// 仕様書 セクション2〜6 の還元データを初期投入する
class DatabaseInitializer {
  static const List<Map<String, dynamic>> _payments = [
    {
      'name': 'Oliveフレキシブルペイ ゴールド',
      'type': 'credit',
      'issuer': '三井住友銀行',
      'base_rate': 0.5,
      'annual_fee': 5500,
      'color': '#B8860B',
      'note': '年100万円利用で永年無料＋10,000Vポイント。Vポイントアッププログラム対応。',
    },
    {
      'name': '三井住友カード ゴールド(NL)',
      'type': 'credit',
      'issuer': '三井住友カード',
      'base_rate': 0.5,
      'annual_fee': 5500,
      'color': '#C0A062',
      'note': '年100万円利用で永年無料＋10,000Vポイント。対象店スマホタッチ最大7%。',
    },
    {
      'name': 'V NEOBANK デビット',
      'type': 'debit',
      'issuer': '住信SBIネット銀行',
      'base_rate': 1.5,
      'annual_fee': 0,
      'color': '#2E7D32',
      'note': '月1,000円以上利用時、月間利用額×1.5%。いつでも1.5%。',
    },
    {
      'name': '三菱UFJカード',
      'type': 'credit',
      'issuer': '三菱UFJニコス',
      'base_rate': 0.5,
      'annual_fee': 0,
      'color': '#D32F2F',
      'note': '対象店で最大7%~20%。セブン・ローソン・松屋・スシロー等で強い。',
    },
    {
      'name': 'PayPayカード',
      'type': 'credit',
      'issuer': 'PayPayカード',
      'base_rate': 1.0,
      'annual_fee': 0,
      'color': '#E53935',
      'note': 'PayPayステップで最大1.5%。Yahoo!ショッピングで強い。',
    },
    {
      'name': 'VポイントPay',
      'type': 'qr',
      'issuer': '三井住友カード',
      'base_rate': 0.5,
      'annual_fee': 0,
      'color': '#1976D2',
      'note': 'V NEOBANKデビットチャージで合計約2.0%。QR/コード払いに変換可能。',
    },
    {
      'name': '楽天カード',
      'type': 'credit',
      'issuer': '楽天カード',
      'base_rate': 1.0,
      'annual_fee': 0,
      'color': '#BF0000',
      'note': '楽天市場でSPU最大18倍。5と0のつく日+2倍。',
    },
    {
      'name': 'JCBカードW',
      'type': 'credit',
      'issuer': 'JCB',
      'base_rate': 1.0,
      'annual_fee': 0,
      'color': '#0D47A1',
      'note': 'JCBオリジナルパートナー店で還元UP。Amazon 2%、スタバ最大10.5%。',
    },
    {
      'name': 'メルカード',
      'type': 'credit',
      'issuer': 'メルペイ',
      'base_rate': 1.0,
      'annual_fee': 0,
      'color': '#FF0211',
      'note': 'メルカリ利用で最大4%（実績連動）。',
    },
  ];

  // 決済ID (1-origin)
  static const int pOlive = 1;
  static const int pSmbcNlGold = 2;
  static const int pVneobank = 3;
  static const int pMufg = 4;
  static const int pPaypay = 5;
  static const int pVpointPay = 6;
  static const int pRakuten = 7;
  static const int pJcbW = 8;
  static const int pMercard = 9;

  static const List<Map<String, dynamic>> _stores = [
    // コンビニ
    {'name': 'セブン-イレブン', 'category': 'convenience', 'aliases': 'セブン,711,7-eleven,7イレブン', 'icon': '🏪'},
    {'name': 'ローソン', 'category': 'convenience', 'aliases': 'lawson,ろーそん', 'icon': '🏪'},
    {'name': 'ファミリーマート', 'category': 'convenience', 'aliases': 'ファミマ,familymart', 'icon': '🏪'},
    {'name': 'ミニストップ', 'category': 'convenience', 'aliases': 'ministop', 'icon': '🏪'},
    {'name': 'デイリーヤマザキ', 'category': 'convenience', 'aliases': 'daily', 'icon': '🏪'},
    {'name': 'セイコーマート', 'category': 'convenience', 'aliases': 'seicomart,セコマ', 'icon': '🏪'},
    // ファミレス／飲食
    {'name': 'サイゼリヤ', 'category': 'restaurant', 'aliases': 'saizeriya,さいぜりや', 'icon': '🍝'},
    {'name': '松屋', 'category': 'restaurant', 'aliases': 'matsuya', 'icon': '🍱'},
    {'name': 'マクドナルド', 'category': 'restaurant', 'aliases': 'macdonalds,マック,マクド', 'icon': '🍔'},
    {'name': 'ガスト', 'category': 'restaurant', 'aliases': 'gusto,すかいらーく', 'icon': '🍴'},
    {'name': 'バーミヤン', 'category': 'restaurant', 'aliases': 'bamiyan,すかいらーく', 'icon': '🥟'},
    {'name': 'ジョナサン', 'category': 'restaurant', 'aliases': 'jonathan,すかいらーく', 'icon': '🍴'},
    {'name': 'スシロー', 'category': 'restaurant', 'aliases': 'sushiro', 'icon': '🍣'},
    {'name': 'くら寿司', 'category': 'restaurant', 'aliases': 'kurazushi', 'icon': '🍣'},
    {'name': 'ケンタッキー', 'category': 'restaurant', 'aliases': 'kfc,ケンタ', 'icon': '🍗'},
    {'name': '吉野家', 'category': 'restaurant', 'aliases': 'yoshinoya', 'icon': '🍱'},
    {'name': 'すき家', 'category': 'restaurant', 'aliases': 'sukiya', 'icon': '🍱'},
    {'name': 'モスバーガー', 'category': 'restaurant', 'aliases': 'mos,モス', 'icon': '🍔'},
    // カフェ
    {'name': 'スターバックス', 'category': 'cafe', 'aliases': 'starbucks,スタバ', 'icon': '☕'},
    {'name': 'ドトール', 'category': 'cafe', 'aliases': 'doutor', 'icon': '☕'},
    {'name': 'タリーズ', 'category': 'cafe', 'aliases': 'tullys', 'icon': '☕'},
    {'name': 'ミスタードーナツ', 'category': 'cafe', 'aliases': 'misdo,ミスド', 'icon': '🍩'},
    // ドラッグストア
    {'name': 'ウェルシア', 'category': 'drugstore', 'aliases': 'welcia,ウエルシア', 'icon': '💊'},
    {'name': 'マツモトキヨシ', 'category': 'drugstore', 'aliases': 'matsukiyo,マツキヨ', 'icon': '💊'},
    {'name': 'ツルハドラッグ', 'category': 'drugstore', 'aliases': 'tsuruha', 'icon': '💊'},
    {'name': 'サンドラッグ', 'category': 'drugstore', 'aliases': 'sundrug', 'icon': '💊'},
    {'name': 'ココカラファイン', 'category': 'drugstore', 'aliases': 'cocokara', 'icon': '💊'},
    // 100均
    {'name': 'ダイソー', 'category': 'discount', 'aliases': 'daiso,100均', 'icon': '💯'},
    {'name': 'キャンドゥ', 'category': 'discount', 'aliases': 'candodo,can do', 'icon': '💯'},
    // EC
    {'name': 'Amazon', 'category': 'ec', 'aliases': 'amazon,アマゾン', 'icon': '📦'},
    {'name': 'ヨドバシ.com', 'category': 'ec', 'aliases': 'yodobashi,ヨドバシ', 'icon': '🏬'},
    {'name': 'Yahoo!ショッピング', 'category': 'ec', 'aliases': 'yahoo,yahooshopping,ヤフショ', 'icon': '🛍️'},
    {'name': '楽天市場', 'category': 'ec', 'aliases': 'rakuten,楽天', 'icon': '🛒'},
    {'name': 'メルカリ', 'category': 'ec', 'aliases': 'mercari', 'icon': '📱'},
    {'name': 'LOHACO', 'category': 'ec', 'aliases': 'lohaco,ロハコ', 'icon': '🛍️'},
    // スーパー
    {'name': 'イオン', 'category': 'supermarket', 'aliases': 'aeon,イオンモール', 'icon': '🛒'},
    {'name': '西友', 'category': 'supermarket', 'aliases': 'seiyu', 'icon': '🛒'},
    {'name': 'イトーヨーカドー', 'category': 'supermarket', 'aliases': 'ito yokado,ヨーカドー', 'icon': '🛒'},
    {'name': 'ライフ', 'category': 'supermarket', 'aliases': 'life', 'icon': '🛒'},
    {'name': '業務スーパー', 'category': 'supermarket', 'aliases': 'gyomu', 'icon': '🛒'},
    {'name': 'オーケー', 'category': 'supermarket', 'aliases': 'OK,ok store', 'icon': '🛒'},
    // 百貨店
    {'name': '高島屋', 'category': 'department', 'aliases': 'takashimaya', 'icon': '🏬'},
    {'name': '三越伊勢丹', 'category': 'department', 'aliases': 'mitsukoshi,isetan', 'icon': '🏬'},
    {'name': '東急百貨店', 'category': 'department', 'aliases': 'tokyu', 'icon': '🏬'},
    {'name': '東武百貨店', 'category': 'department', 'aliases': 'tobu', 'icon': '🏬'},
    {'name': '大丸松坂屋', 'category': 'department', 'aliases': 'daimaru,matsuzakaya', 'icon': '🏬'},
    // 交通
    {'name': 'JR東日本(Suica)', 'category': 'transit', 'aliases': 'jr,suica,jr east', 'icon': '🚊'},
    {'name': 'JR西日本(ICOCA)', 'category': 'transit', 'aliases': 'jr west,icoca', 'icon': '🚊'},
    {'name': '東京メトロ', 'category': 'transit', 'aliases': 'tokyo metro', 'icon': '🚇'},
    {'name': '東急電鉄', 'category': 'transit', 'aliases': 'tokyu line', 'icon': '🚊'},
    {'name': '東武鉄道', 'category': 'transit', 'aliases': 'tobu line', 'icon': '🚊'},
    {'name': '全国バス・路面電車(タッチ)', 'category': 'transit', 'aliases': 'bus,touch', 'icon': '🚌'},
    {'name': 'ANA', 'category': 'transit', 'aliases': 'ana', 'icon': '✈️'},
    {'name': 'JAL', 'category': 'transit', 'aliases': 'jal', 'icon': '✈️'},
    // ガソリン
    {'name': 'ENEOS', 'category': 'gas', 'aliases': 'eneos,エネオス', 'icon': '⛽'},
    {'name': '出光', 'category': 'gas', 'aliases': 'idemitsu', 'icon': '⛽'},
    {'name': '昭和シェル', 'category': 'gas', 'aliases': 'shell', 'icon': '⛽'},
    {'name': 'コスモ', 'category': 'gas', 'aliases': 'cosmo', 'icon': '⛽'},
  ];

  // ストアID (1-origin)
  static const int sSeven = 1, sLawson = 2, sFamima = 3, sMinistop = 4, sDaily = 5, sSeico = 6;
  static const int sSaize = 7, sMatsuya = 8, sMcd = 9, sGusto = 10, sBamiyan = 11, sJonathan = 12;
  static const int sSushiro = 13, sKura = 14, sKfc = 15, sYoshinoya = 16, sSukiya = 17, sMos = 18;
  static const int sStarbucks = 19, sDoutor = 20, sTullys = 21, sMisdo = 22;
  static const int sWelcia = 23, sMatsukiyo = 24, sTsuruha = 25, sSundrug = 26, sCocokara = 27;
  static const int sDaiso = 28, sCando = 29;
  static const int sAmazon = 30, sYodobashi = 31, sYahoo = 32, sRakutenIchiba = 33, sMercari = 34, sLohaco = 35;
  static const int sAeon = 36, sSeiyu = 37, sYokado = 38, sLife = 39, sGyomu = 40, sOk = 41;
  static const int sTakashimaya = 42, sMitsukoshi = 43, sTokyuDept = 44, sTobuDept = 45, sDaimaru = 46;
  static const int sJrEast = 47, sJrWest = 48, sMetro = 49, sTokyu = 50, sTobu = 51, sBus = 52, sAna = 53, sJal = 54;
  static const int sEneos = 55, sIdemitsu = 56, sShell = 57, sCosmo = 58;

  static List<Map<String, dynamic>> _rules() => [
        // セブン-イレブン
        {'s': sSeven, 'p': pSmbcNlGold, 'b': 6.5, 'm': 10.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチ決済で最大10%~11%（セブン特別）'},
        {'s': sSeven, 'p': pOlive, 'b': 6.5, 'm': 10.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチ決済で最大10%~11%（セブン特別）'},
        {'s': sSeven, 'p': pMufg, 'b': 6.5, 'm': 12.0, 'c': 'mufg_program', 'n': 'QUICPay/Apple Pay経由で7%、ポイントアップで最大20%'},
        {'s': sSeven, 'p': pJcbW, 'b': 1.0, 'm': 1.0, 'c': '', 'n': 'JCBオリジナルパートナー店 2.0%'},
        {'s': sSeven, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '基本1.5%還元'},
        {'s': sSeven, 'p': pPaypay, 'b': 0.0, 'm': 0.5, 'c': 'paypay_step', 'n': 'PayPay経由で最大1.5%'},
        {'s': sSeven, 'p': pVpointPay, 'b': 0.0, 'm': 0.0, 'c': '', 'n': 'V NEOBANKチャージで合計2.0%'},
        // ローソン
        {'s': sLawson, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': '対象店スマホタッチ7%＋Vアップで最大20%'},
        {'s': sLawson, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': '対象店スマホタッチ7%＋Vアップで最大20%'},
        {'s': sLawson, 'p': pMufg, 'b': 6.5, 'm': 12.0, 'c': 'mufg_program', 'n': 'QUICPay経由で7%、ポイントアップで最大20%'},
        {'s': sLawson, 'p': pJcbW, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '基本1%'},
        {'s': sLawson, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '基本1.5%還元'},
        {'s': sLawson, 'p': pPaypay, 'b': 0.0, 'm': 0.5, 'c': 'paypay_step', 'n': 'PayPay経由で最大1.5%'},
        {'s': sLawson, 'p': pVpointPay, 'b': 0.0, 'm': 0.0, 'c': '', 'n': 'V NEOBANKチャージで合計2.0%'},
        // ファミマ
        {'s': sFamima, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': '対象店スマホタッチ7%'},
        {'s': sFamima, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': '対象店スマホタッチ7%'},
        {'s': sFamima, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '基本1.5%還元'},
        {'s': sFamima, 'p': pPaypay, 'b': 0.0, 'm': 0.5, 'c': 'paypay_step', 'n': '最大1.5%'},
        {'s': sFamima, 'p': pJcbW, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '基本1%'},
        // ミニストップ・デイリー・セイコーマート
        for (final s in [sMinistop, sDaily, sSeico]) ...[
          {'s': s, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': '対象店スマホタッチ7%'},
          {'s': s, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': '対象店スマホタッチ7%'},
          {'s': s, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '基本1.5%還元'},
        ],
        // サイゼリヤ
        {'s': sSaize, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%、Vアップで最大20%'},
        {'s': sSaize, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%、Vアップで最大20%'},
        {'s': sSaize, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '安定1.5%'},
        {'s': sSaize, 'p': pPaypay, 'b': 0.0, 'm': 0.5, 'c': 'paypay_step', 'n': '最大1.5%'},
        {'s': sSaize, 'p': pJcbW, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '基本1%'},
        // 松屋
        {'s': sMatsuya, 'p': pMufg, 'b': 6.5, 'm': 14.5, 'c': 'mufg_program', 'n': '三菱UFJの対象店。最大7~15%(松屋アプリ事前決済で最大40%)'},
        {'s': sMatsuya, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
        {'s': sMatsuya, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
        {'s': sMatsuya, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '安定1.5%'},
        {'s': sMatsuya, 'p': pPaypay, 'b': 0.0, 'm': 0.5, 'c': 'paypay_step', 'n': '事前決済キャンペーン時さらに高還元'},
        // マクドナルド
        {'s': sMcd, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'モバイルオーダー/スマホタッチで7%、Vアップで最大20%'},
        {'s': sMcd, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'モバイルオーダー/スマホタッチで7%、Vアップで最大20%'},
        {'s': sMcd, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        {'s': sMcd, 'p': pPaypay, 'b': 0.0, 'm': 0.5, 'c': 'paypay_step', 'n': '最大1.5%'},
        {'s': sMcd, 'p': pJcbW, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '基本1%'},
        // ガスト/バーミヤン/ジョナサン
        for (final s in [sGusto, sBamiyan, sJonathan]) ...[
          {'s': s, 'p': pJcbW, 'b': 9.5, 'm': 9.5, 'c': '', 'n': 'JCBオリジナルパートナーで10.5%'},
          {'s': s, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
          {'s': s, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
          {'s': s, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        ],
        // スシロー
        {'s': sSushiro, 'p': pMufg, 'b': 6.5, 'm': 14.5, 'c': 'mufg_program', 'n': '三菱UFJ対象店で7~15%'},
        {'s': sSushiro, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
        {'s': sSushiro, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
        {'s': sSushiro, 'p': pJcbW, 'b': 1.0, 'm': 1.0, 'c': '', 'n': 'JCBパートナーで2.0%'},
        {'s': sSushiro, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // くら寿司
        {'s': sKura, 'p': pMufg, 'b': 6.5, 'm': 14.5, 'c': 'mufg_program', 'n': '三菱UFJ対象店で7~15%'},
        {'s': sKura, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // ケンタッキー
        {'s': sKfc, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
        {'s': sKfc, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
        {'s': sKfc, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // 吉野家
        {'s': sYoshinoya, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
        {'s': sYoshinoya, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
        {'s': sYoshinoya, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // すき家
        {'s': sSukiya, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // モスバーガー
        {'s': sMos, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
        {'s': sMos, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
        {'s': sMos, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // スターバックス
        {'s': sStarbucks, 'p': pJcbW, 'b': 9.5, 'm': 9.5, 'c': '', 'n': 'スタバカード オンライン入金/eGiftで最大10.5%'},
        {'s': sStarbucks, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'モバイルオーダーで7%'},
        {'s': sStarbucks, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'モバイルオーダーで7%'},
        {'s': sStarbucks, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // ドトール
        {'s': sDoutor, 'p': pSmbcNlGold, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
        {'s': sDoutor, 'p': pOlive, 'b': 6.5, 'm': 12.5, 'c': 'smbc_vpoint', 'n': 'スマホタッチで7%'},
        {'s': sDoutor, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // タリーズ
        {'s': sTullys, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // ミスタードーナツ
        {'s': sMisdo, 'p': pRakuten, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '楽天ポイント連携可'},
        {'s': sMisdo, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // ウェルシア
        {'s': sWelcia, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': 'ウエル活ルートのチャージ源として最強'},
        {'s': sWelcia, 'p': pPaypay, 'b': 0.0, 'm': 0.5, 'c': 'paypay_step', 'n': '最大1.5%'},
        // マツモトキヨシ・ツルハ・サンドラッグ・ココカラ
        for (final s in [sMatsukiyo, sTsuruha, sSundrug, sCocokara]) ...[
          {'s': s, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
          {'s': s, 'p': pRakuten, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '楽天ポイント連携可'},
        ],
        // ダイソー・キャンドゥ
        for (final s in [sDaiso, sCando]) ...[
          {'s': s, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '安定1.5%(最強)'},
          {'s': s, 'p': pRakuten, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1%'},
          {'s': s, 'p': pJcbW, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1%'},
          {'s': s, 'p': pPaypay, 'b': 0.0, 'm': 0.5, 'c': 'paypay_step', 'n': '最大1.5%'},
        ],
        // Amazon
        {'s': sAmazon, 'p': pJcbW, 'b': 1.0, 'm': 1.0, 'c': '', 'n': 'JCBオリジナルパートナーで2.0%'},
        {'s': sAmazon, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        {'s': sAmazon, 'p': pPaypay, 'b': 0.0, 'm': 0.5, 'c': 'paypay_step', 'n': '最大1.5%'},
        {'s': sAmazon, 'p': pRakuten, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '基本1%'},
        // ヨドバシ.com
        {'s': sYodobashi, 'p': pVneobank, 'b': 8.0, 'm': 8.0, 'c': '', 'n': 'ヨドバシ8%+デビット1.5% = 計9.5%相当'},
        {'s': sYodobashi, 'p': pJcbW, 'b': 8.0, 'm': 8.0, 'c': '', 'n': 'ヨドバシ8%+JCBW1% = 計9%相当'},
        {'s': sYodobashi, 'p': pSmbcNlGold, 'b': 8.0, 'm': 8.0, 'c': '', 'n': 'ヨドバシ8%+SMBC0.5%'},
        // Yahoo!ショッピング
        {'s': sYahoo, 'p': pPaypay, 'b': 2.0, 'm': 7.0, 'c': 'lyp_premium', 'n': 'LYPプレミアム+日曜日で計5%以上'},
        {'s': sYahoo, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // LOHACO
        {'s': sLohaco, 'p': pPaypay, 'b': 2.0, 'm': 7.0, 'c': 'lyp_premium', 'n': 'LYPプレミアム連携で高還元'},
        // 楽天市場
        {'s': sRakutenIchiba, 'p': pRakuten, 'b': 2.0, 'm': 16.0, 'c': 'rakuten_spu', 'n': 'SPU項目達成で最大18倍'},
        {'s': sRakutenIchiba, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // メルカリ
        {'s': sMercari, 'p': pMercard, 'b': 3.0, 'm': 3.0, 'c': '', 'n': '実績連動で最大4%'},
        {'s': sMercari, 'p': pJcbW, 'b': 1.0, 'm': 1.0, 'c': '', 'n': 'JCBオリジナルパートナーで2.0%'},
        {'s': sMercari, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // イオン
        {'s': sAeon, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // イトーヨーカドー
        {'s': sYokado, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%(8の付く日5%OFFは別)'},
        // 業務スーパー・ライフ・西友
        for (final s in [sGyomu, sLife, sSeiyu]) ...[
          {'s': s, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        ],
        // オーケー
        {'s': sOk, 'p': pMufg, 'b': 6.5, 'm': 12.0, 'c': 'mufg_program', 'n': '三菱UFJ対象店で最大20%'},
        {'s': sOk, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        // 高島屋
        {'s': sTakashimaya, 'p': pJcbW, 'b': 1.0, 'm': 1.0, 'c': '', 'n': 'JCBパートナーで2.0%'},
        // 百貨店
        for (final s in [sMitsukoshi, sTokyuDept, sTobuDept, sDaimaru]) ...[
          {'s': s, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        ],
        // 交通: タッチ決済 (2026/4/13~)
        for (final s in [sJrEast, sJrWest, sMetro, sTokyu, sTobu, sBus]) ...[
          {'s': s, 'p': pSmbcNlGold, 'b': 7.5, 'm': 7.5, 'c': '', 'n': 'スマホタッチ乗車で最大8%（2026/4/13~）'},
          {'s': s, 'p': pOlive, 'b': 7.5, 'm': 7.5, 'c': '', 'n': 'スマホタッチ乗車で最大8%（2026/4/13~）'},
          {'s': s, 'p': pVneobank, 'b': 0.0, 'm': 0.0, 'c': '', 'n': '1.5%'},
        ],
      ];

  static Future<void> seed(Database db) async {
    final batch = db.batch();

    for (final p in _payments) {
      batch.insert('payment_methods', {
        'name': p['name'],
        'type': p['type'],
        'issuer': p['issuer'],
        'base_rate': p['base_rate'],
        'annual_fee': p['annual_fee'],
        'enabled': 1,
        'color': p['color'],
        'note': p['note'],
      });
    }

    for (final s in _stores) {
      batch.insert('stores', {
        'name': s['name'],
        'category': s['category'],
        'aliases': s['aliases'] ?? '',
        'icon': s['icon'] ?? '🏪',
        'is_favorite': 0,
      });
    }

    for (final r in _rules()) {
      batch.insert('reward_rules', {
        'store_id': r['s'],
        'payment_id': r['p'],
        'base_bonus': r['b'],
        'max_bonus': r['m'],
        'condition_key': r['c'],
        'note': r['n'],
      });
    }

    await batch.commit(noResult: true);
  }
}

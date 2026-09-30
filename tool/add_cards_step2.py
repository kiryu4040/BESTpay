#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""店舗・条件・ルールを追加する（D-143）。"""
import json, os, copy, hashlib

D = 'assets/data'
VER = '2026.10.01.1'
TODAY = '2026-10-01'


def load(f):
    return json.load(open(os.path.join(D, f)))


def save(f, o):
    if isinstance(o, dict) and 'catalogVersion' in o:
        o['catalogVersion'] = VER
    with open(os.path.join(D, f), 'w') as fh:
        json.dump(o, fh, ensure_ascii=False, indent=2)
        fh.write('\n')


# --------------------------------------------------------------------------
# 1. カテゴリ
# --------------------------------------------------------------------------
cj = load('merchant_categories.json')
C = cj['items']
if not any(c['id'] == 'book_media' for c in C):
    C.append({
        'id': 'book_media', 'name': '書店・音楽・娯楽', 'parentCategoryId': None,
        'status': 'active',
        'sourceIds': ['src_dcard_official', 'src_dpoint_tokuyaku_about'],
        'notes': ['dカード特約店に書店・レコード店・カラオケが複数掲載されているため新設した（D-143）。'],
    })
save('merchant_categories.json', cj)

# --------------------------------------------------------------------------
# 2. 店舗
# --------------------------------------------------------------------------
mj = load('merchants.json')
M = mj['items']
byid = {m['id']: m for m in M}

AEON_SRC = ['src_aeon_card_official', 'src_aeon_point_official', 'src_aeon_anytime_double', 'src_aeon_thanks_day']
WELCIA_SRC = ['src_aeon_welcia_card', 'src_aeon_point_official']
DCARD_SRC = ['src_dcard_official', 'src_dpoint_tokuyaku_about']
PAYPAY_SRC = ['src_paypay_card_point']


def mk(mid, name, cat, notes, srcs, aliases=None, group=None):
    return {'id': mid, 'name': name,
            'merchantGroupIds': [group] if group else [],
            'categoryIds': [cat], 'locationIds': [], 'status': 'active',
            'sourceIds': srcs, 'notes': notes,
            **({'searchAliases': aliases} if aliases else {})}


NEW = [
    # ---- イオングループ（いつでも2倍・お客さま感謝デー）----
    mk('maxvalu', 'マックスバリュ', 'supermarket',
       ['イオングループの対象店舗。イオンマークのカード払いでいつでも200円2WAON POINT（1.0%）。毎月20日・30日のお客さま感謝デーは5%OFF。'],
       AEON_SRC, ['まっくすばりゅ', 'マックスバリュー'], 'supermarket_chain'),
    mk('the_big', 'ザ・ビッグ', 'supermarket',
       ['イオングループの対象店舗。イオンマークのカード払いでいつでも200円2WAON POINT（1.0%）。毎月20日・30日のお客さま感謝デーは5%OFF。'],
       AEON_SRC, ['ざびっぐ', 'ビッグ'], 'supermarket_chain'),
    mk('aeon_style', 'イオンスタイル', 'supermarket',
       ['イオングループの対象店舗。いつでも200円2WAON POINT。毎月10日のありが10デーはイオンカードで5倍（AEON Payは10倍）、毎月20日・30日は5%OFF。'],
       AEON_SRC, ['いおんすたいる', 'イオンスタイル'], 'supermarket_chain'),
    mk('daiei', 'ダイエー', 'supermarket',
       ['イオングループの対象店舗。イオンマークのカード払いでいつでも200円2WAON POINT（1.0%）。毎月20日・30日のお客さま感謝デーは5%OFF。'],
       AEON_SRC, ['だいえー'], 'supermarket_chain'),
    mk('aeon_supercenter', 'イオンスーパーセンター', 'supermarket',
       ['イオングループの対象店舗。イオンマークのカード払いでいつでも200円2WAON POINT（1.0%）。毎月20日・30日のお客さま感謝デーは5%OFF。'],
       AEON_SRC, ['いおんすーぱーせんたー'], 'supermarket_chain'),
    mk('sunday', 'サンデー', 'supermarket',
       ['イオングループの対象店舗。イオンマークのカード払いでいつでも200円2WAON POINT（1.0%）。毎月20日・30日のお客さま感謝デーは5%OFF。'],
       AEON_SRC, ['さんでー'], 'supermarket_chain'),
    mk('maibasket', 'まいばすけっと', 'supermarket',
       ['イオングループの対象店舗。イオンマークのカード払いでいつでも200円2WAON POINT（1.0%）。'],
       AEON_SRC, ['まいばすけっと'], 'supermarket_chain'),

    # ---- ウエルシアグループ（クレジット1.5%・毎月10日10%）----
    mk('welcia', 'ウエルシア', 'drugstore',
       ['ウエルシアグループの対象店舗。ウエルシアカードのクレジット払いで200円3WAON POINT（1.5%）、毎月10日は200円20WAON POINT（10%）。カード提示を併用すると最大11%。'],
       WELCIA_SRC, ['うえるしあ', 'ウエルシア薬局'], 'drugstore_chain'),
    mk('hac_drug', 'ハックドラッグ', 'drugstore',
       ['ウエルシアグループの対象店舗。ウエルシアカードのクレジット払いで1.5%、毎月10日は10%。'],
       WELCIA_SRC, ['はっくどらっぐ', 'ハック'], 'drugstore_chain'),
    mk('kokumin', 'コクミン', 'drugstore',
       ['ウエルシアグループの対象店舗。ウエルシアカードのクレジット払いで1.5%、毎月10日は10%。dカード特約店でもある（100円につき+2ポイント）。'],
       WELCIA_SRC + DCARD_SRC, ['こくみん', 'コクミンドラッグ'], 'drugstore_chain'),
    mk('kinko_yakuhin', '金光薬品', 'drugstore',
       ['ウエルシアグループの対象店舗。ウエルシアカードのクレジット払いで1.5%、毎月10日は10%。'],
       WELCIA_SRC, ['きんこうやくひん'], 'drugstore_chain'),
    mk('dax_drug', 'ダックス', 'drugstore',
       ['ウエルシアグループの対象店舗。ウエルシアカードのクレジット払いで1.5%、毎月10日は10%。'],
       WELCIA_SRC, ['だっくす'], 'drugstore_chain'),
    mk('super_drug_himawari', 'スーパードラッグひまわり', 'drugstore',
       ['ウエルシアグループの対象店舗。ウエルシアカードのクレジット払いで1.5%、毎月10日は10%。'],
       WELCIA_SRC, ['ひまわり', 'すーぱーどらっぐひまわり'], 'drugstore_chain'),
    mk('maruedrug', 'マルエドラッグ', 'drugstore',
       ['ウエルシアグループの対象店舗。ウエルシアカードのクレジット払いで1.5%、毎月10日は10%。'],
       WELCIA_SRC, ['まるえどらっぐ'], 'drugstore_chain'),
    mk('happy_drug', 'ハッピー・ドラッグ', 'drugstore',
       ['ウエルシアグループの対象店舗。ウエルシアカードのクレジット払いで1.5%、毎月10日は10%。'],
       WELCIA_SRC, ['はっぴーどらっぐ'], 'drugstore_chain'),
    mk('yodoya_drug', 'よどやドラッグ', 'drugstore',
       ['ウエルシアグループの対象店舗。ウエルシアカードのクレジット払いで1.5%、毎月10日は10%。'],
       WELCIA_SRC, ['よどや'], 'drugstore_chain'),
    mk('fuku_yakuhin', 'ふく薬品', 'drugstore',
       ['ウエルシアグループの対象店舗。ウエルシアカードのクレジット払いで1.5%、毎月10日は10%。JCBカードWのJ-POINTパートナーでもある（2倍）。'],
       WELCIA_SRC, ['ふくやくひん'], 'drugstore_chain'),
    mk('towoya_yakkyoku', 'とをしや薬局', 'drugstore',
       ['ウエルシアグループの対象店舗。ウエルシアカードのクレジット払いで1.5%、毎月10日は10%。'],
       WELCIA_SRC, ['とをしや'], 'drugstore_chain'),

    # ---- dカード特約店 ----
    mk('matsumotokiyoshi', 'マツモトキヨシ', 'drugstore',
       ['dカード特約店（100円につき+2ポイント）。dカードの基本1%と合算して3%。'],
       DCARD_SRC, ['まつきよ', 'マツキヨ', 'まつもときよし'], 'drugstore_chain'),
    mk('cocokara_fine', 'ココカラファイン', 'drugstore',
       ['dカード特約店（100円につき+2ポイント）。dカードの基本1%と合算して3%。'],
       DCARD_SRC, ['ここからふぁいん', 'ココカラ'], 'drugstore_chain'),
    mk('takashimaya', '高島屋', 'department_store',
       ['dカード特約店（200円につき+1ポイント）。dカードの基本1%と合算して1.5%。'],
       DCARD_SRC, ['たかしまや', 'タカシマヤ'], 'department_store_chain'),
    mk('kinokuniya', '紀伊國屋書店', 'book_media',
       ['dカード特約店（100円につき+1ポイント）。dカードの基本1%と合算して2%。'],
       DCARD_SRC, ['きのくにや', '紀伊国屋書店']),
    mk('maruzen', '丸善', 'book_media',
       ['dカード特約店（200円につき+1ポイント）。dカードの基本1%と合算して1.5%。'],
       DCARD_SRC, ['まるぜん']),
    mk('junku_do', 'ジュンク堂書店', 'book_media',
       ['dカード特約店（200円につき+1ポイント）。dカードの基本1%と合算して1.5%。'],
       DCARD_SRC, ['じゅんくどう', 'ジュンク堂']),
    mk('tower_records', 'タワーレコード', 'book_media',
       ['dカード特約店（100円につき+1ポイント）。dカードの基本1%と合算して2%。'],
       DCARD_SRC, ['たわーれこーど', 'タワレコ']),
    mk('big_echo', 'カラオケビッグエコー', 'book_media',
       ['dカード特約店（100円につき+2ポイント）。dカードの基本1%と合算して3%。'],
       DCARD_SRC, ['びっぐえこー', 'ビッグエコー']),
    mk('golf_me', 'GOLF me!', 'book_media',
       ['dカード特約店（100円につき+4ポイント）。dカードの基本1%と合算して5%。'],
       DCARD_SRC, ['ごるふみー', 'ゴルフミー']),
    mk('club_med', 'クラブメッド', 'lifestyle',
       ['dカード特約店（100円につき+3ポイント）。dカードの基本1%と合算して4%。'],
       DCARD_SRC, ['くらぶめっど'], 'lifestyle_chain'),
    mk('sakai_hikkoshi', 'サカイ引越センター', 'lifestyle',
       ['dカード特約店（100円につき+3ポイント）。dカードの基本1%と合算して4%。'],
       DCARD_SRC, ['さかいひっこし', 'サカイ'], 'lifestyle_chain'),
    mk('adidas_online', 'アディダス オンラインショップ', 'fashion',
       ['dカード特約店（100円につき+1ポイント）。dカードの基本1%と合算して2%。'],
       DCARD_SRC, ['あでぃだす', 'adidas'], 'ファッションチェーン'),
    mk('suit_square', 'SUIT SQUARE', 'fashion',
       ['dカード特約店（100円につき+1ポイント）。dカードの基本1%と合算して2%。'],
       DCARD_SRC, ['すーつくえあ', 'スーツスクエア'], 'ファッションチェーン'),

    # ---- PayPayカード ----
    mk('lohaco', 'LOHACO', 'online_shop',
       ['PayPayカードで毎日最大5%（PayPayステップ1%＋ストアポイント1%＋毎日もらえる3%）。PayPayアプリ登録と本人確認が必要。'],
       PAYPAY_SRC, ['ろはこ', 'LOHACO'], 'online_chain'),
]
for m in NEW:
    if m['id'] in byid:
        byid[m['id']].update(m)
    else:
        M.append(m)
        byid[m['id']] = m
save('merchants.json', mj)

AEON_GROUP = ['aeon', 'ministop', 'maxvalu', 'the_big', 'aeon_style', 'daiei',
              'aeon_supercenter', 'sunday', 'maibasket']
AEON_THANKS = ['aeon', 'aeon_style', 'maxvalu', 'aeon_supercenter', 'sunday',
               'the_big', 'daiei', 'maibasket']
AEON_ARIGA10 = ['aeon', 'aeon_style']
WELCIA_GROUP = ['welcia', 'hac_drug', 'kokumin', 'kinko_yakuhin', 'dax_drug',
                'super_drug_himawari', 'maruedrug', 'happy_drug', 'yodoya_drug',
                'fuku_yakuhin', 'towoya_yakkyoku']

# --------------------------------------------------------------------------
# 3. 条件
# --------------------------------------------------------------------------
jj = load('condition_definitions.json')
J = jj['items']
cids = {c['id'] for c in J}
ctmpl = [c for c in J if c['id'] == 'smbc_pup_vitality_gold'][0]

NEW_COND = [
    ('aeon_ariga10_card', '毎月10日の「ありが10デー」（イオンカード払い）',
     '毎月10日にイオン・イオンスタイル直営売場でイオンカード払いをすると、WAON POINTが200円につき5ポイント（基本の5倍）になる。',
     ['イオンカード', 'aeon_card'],
     ['毎月10日だけの特典。当日に買い物をするときだけ「満たす」にしてください。',
      'AEON Payのスマホ決済を使う場合は、もう一方の条件（AEON Pay）だけをオンにしてください。両方をオンにすると還元率が過大になります。',
      '対象は本州（東北を除く）・四国のイオン／イオンスタイル直営売場。調剤・たばこ・切手・商品券などは対象外。'],
     ['src_aeon_ariga10', 'src_aeon_card_official']),
    ('aeon_ariga10_aeonpay', '毎月10日の「ありが10デー」（AEON Payのスマホ決済）',
     '毎月10日にイオン・イオンスタイル直営売場でAEON Payのスマホ決済をすると、WAON POINTが200円につき10ポイント（基本の10倍）になる。',
     ['イオンカード', 'aeon_card'],
     ['毎月10日だけの特典。AEON Payで支払うときだけ「満たす」にしてください。',
      'イオンカード払いの場合は、もう一方の条件（イオンカード払い）だけをオンにしてください。',
      '対象は本州（東北を除く）・四国のイオン／イオンスタイル直営売場。'],
     ['src_aeon_ariga10', 'src_aeon_card_official']),
    ('aeon_thanks_day', '毎月20日・30日の「お客さま感謝デー」',
     '毎月20日・30日にイオングループの対象店舗でイオンマークのカード払い・AEON Pay・イオンiD・電子マネーWAONなどで支払うと、買い物代金が5%OFFになる。',
     ['イオンカード', 'aeon_card'],
     ['毎月20日と30日だけの特典。当日に買い物をするときだけ「満たす」にしてください。',
      'これはポイント進呈ではなく買い物代金の値引きです。アプリでは値引き額を同額の還元として円換算で表示します。',
      '一部対象外店舗・対象外商品がある。交通系電子マネーは対象外。'],
     ['src_aeon_thanks_day', 'src_aeon_card_official']),
    ('welcia_10th_day', '毎月10日（ウエルシアカードの10%デー）',
     '毎月10日にウエルシアグループの対象店舗でウエルシアカードをクレジット払いすると、WAON POINTが200円につき20ポイント（10%）になる。カード提示を併せると最大11%。',
     ['ウエルシアカード', 'welcia_card'],
     ['毎月10日だけの特典。当日に買い物をするときだけ「満たす」にしてください。',
      'カード提示のみの場合は1%、クレジット払いのみの場合は10%、両方なら最大11%。',
      '付与は1%分が当月25日、残り9%分が翌月25日。',
      'ウェルパークは対象外。'],
     ['src_aeon_welcia_card']),
    ('paypay_step_achieved', 'PayPayステップの条件達成（200円以上30回＆10万円以上）',
     '直近の判定期間にPayPayカードでの決済が200円以上30回かつ合計10万円以上あると、翌期間の付与率に0.5%が加算される。',
     ['PayPayカード', 'paypay_card'],
     ['判定期間と適用期間はPayPayステップの規定による。',
      '達成していない期間は基本の1.0%のみ。'],
     ['src_paypay_card_point', 'src_paypay_step']),
    ('paypay_app_verified', 'PayPayアプリ登録と本人確認（eKYC）済み',
     'PayPayアプリにPayPayカードを登録し、PayPayの本人確認（eKYC）を完了していると、Yahoo!ショッピング・LOHACOの特典（毎日最大5%）やPayPayステップの対象になる。',
     ['PayPayカード', 'paypay_card'],
     ['Yahoo!ショッピング・LOHACOの「毎日最大5%」にはアプリ登録と本人確認が必要。',
      '未完了の場合は基本付与率のみ。'],
     ['src_paypay_card_point', 'src_paypay_step']),
]
for cid, name, desc, owners, notes, srcs in NEW_COND:
    if cid in cids:
        continue
    c = copy.deepcopy(ctmpl)
    c.update({'id': cid, 'name': name, 'description': desc,
              'valueType': 'boolean', 'defaultState': 'notSatisfied',
              'verificationMethod': 'userInput', 'scope': 'user',
              'sensitivity': 'normal', 'validFrom': TODAY, 'validUntilExclusive': None,
              'status': 'active', 'ownerInstrumentIds': owners,
              'sourceIds': srcs, 'notes': notes})
    J.append(c)
save('condition_definitions.json', jj)

# --------------------------------------------------------------------------
# 4. ルール
# --------------------------------------------------------------------------
rj = load('reward_rules.json')
R = rj['items']
rby = {r['id']: r for r in R}
BASE_T = rby['smbc_gold_nl_base']            # transaction scope の基本還元
BONUS_T = rby['smbc_gold_nl_target_store_bonus']  # billingMonth + aggKey + incremental

NEW_RULES = []


def base_rule(rid, name, desc, inst, unit, pts, program, srcs, notes, valid_from=TODAY, valid_until=None):
    r = copy.deepcopy(BASE_T)
    r.update({'id': rid, 'name': name, 'description': desc, 'ruleKind': 'baseReward',
              'conditionExpression': None,
              'calculation': {'calculationType': 'unitPoints', 'amountUnitYen': unit,
                              'pointsPerUnit': pts, 'rounding': 'floor'},
              'outputPointProgramId': program,
              'validFrom': valid_from, 'validUntilExclusive': valid_until,
              'sourceIds': srcs, 'lastVerifiedAt': TODAY, 'status': 'active',
              'tags': ['base_reward'], 'notes': notes})
    r['selectors']['instrumentIds'] = [inst]
    r['aggregation'] = {'scope': 'transaction', 'aggregationKey': None,
                        'periodMinimumEligibleSpendYen': 0,
                        'conditionEvaluationTiming': 'transaction',
                        'incrementalAward': False}
    return r


def bonus_rule(rid, name, desc, inst, unit, pts, program, merchants, srcs, notes,
               cond=None, kind='campaignBonus', agg=None):
    r = copy.deepcopy(BONUS_T)
    r.update({'id': rid, 'name': name, 'description': desc, 'ruleKind': kind,
              'conditionExpression': ({'nodeType': 'condition', 'conditionId': cond} if cond else None),
              'calculation': {'calculationType': 'unitPoints', 'amountUnitYen': unit,
                              'pointsPerUnit': pts, 'rounding': 'floor'},
              'outputPointProgramId': program,
              'validFrom': TODAY, 'validUntilExclusive': None,
              'sourceIds': srcs, 'lastVerifiedAt': TODAY, 'status': 'active',
              'tags': (['campaign_bonus', 'conditional'] if cond else ['campaign_bonus', 'store_list']),
              'notes': notes})
    r['selectors']['instrumentIds'] = [inst]
    r['selectors']['merchantIds'] = merchants
    r['aggregation'] = {'scope': 'billingMonth',
                        'aggregationKey': agg or ('%s_%d' % (rid, unit)),
                        'periodMinimumEligibleSpendYen': 0,
                        'conditionEvaluationTiming': 'transaction',
                        'incrementalAward': True}
    return r


# ===== イオンカード =====
NEW_RULES += [
    base_rule('aeon_card_base', 'イオンカード 基本還元（200円につき1WAON POINT）',
              'イオンマークのカード払い200円（税込）につき1WAON POINT。', 'aeon_card', 200, 1, 'waon_point',
              ['src_aeon_card_official', 'src_aeon_point_official'],
              ['イオンマークのカード払い200円（税込）につき1WAON POINT（0.5%）。',
               'イオングループの対象店舗では別ルールで2倍（200円2ポイント）になる。',
               '端数処理・月次集計期間の公式明記は未確認のため、取引単位（transaction）で切り捨てを仮定して登録した。']),
    bonus_rule('aeon_card_aeon_group_bonus', 'イオンカード イオングループ対象店舗の上乗せ（いつでも2倍）',
               'イオングループの対象店舗では200円につき1WAON POINTを上乗せし、合計2ポイント（1.0%）にする。',
               'aeon_card', 200, 1, 'waon_point', AEON_GROUP, AEON_SRC,
               ['イオングループの対象店舗ならいつでもWAON POINT基本の2倍（200円2WAON POINT＝1.0%）。',
                '対象は全国のイオン・イオンスタイル・イオンモール・ダイエー・グルメシティ・マックスバリュ・イオンスーパーセンター他。',
                'AEON Payのスマホ決済も対象。AEON Payを除くQRコード・バーコード決済は対象外。',
                '基本還元200円1ポイントと合算して200円2ポイント。',
                'その他のポイント倍付企画と重複せず、高倍率の企画が優先される。']),
    bonus_rule('aeon_card_ariga10_card_bonus', 'イオンカード ありが10デー（イオンカード払い 5倍）',
               '毎月10日にイオン・イオンスタイル直営売場でイオンカード払いをすると、200円につき4WAON POINTを上乗せし合計5ポイントにする。',
               'aeon_card', 200, 4, 'waon_point', AEON_ARIGA10, ['src_aeon_ariga10', 'src_aeon_card_official'],
               ['毎月10日のありが10デー。イオンカード・電子マネーWAONカードの利用で200円につき5ポイント（基本の5倍）。',
                '基本還元200円1ポイントと合算して200円5ポイント＝2.5%。',
                '高倍率優先のため、いつでも2倍（200円2ポイント）は適用されず5ポイントになる。差分4ポイントで登録している。',
                '対象は本州（東北を除く）・四国のイオン／イオンスタイル直営売場。',
                'AEON Payのスマホ決済の場合は別ルール（10倍）。条件はどちらか一方だけをオンにすること。'],
               cond='aeon_ariga10_card'),
    bonus_rule('aeon_card_ariga10_aeonpay_bonus', 'イオンカード ありが10デー（AEON Pay 10倍）',
               '毎月10日にイオン・イオンスタイル直営売場でAEON Payのスマホ決済をすると、200円につき9WAON POINTを上乗せし合計10ポイントにする。',
               'aeon_card', 200, 9, 'waon_point', AEON_ARIGA10, ['src_aeon_ariga10', 'src_aeon_card_official'],
               ['毎月10日のありが10デー。AEON Payのスマホ決済で200円につき10ポイント（基本の10倍）。',
                '基本還元200円1ポイントと合算して200円10ポイント＝5%。',
                '対象は本州（東北を除く）・四国のイオン／イオンスタイル直営売場。',
                'イオンカード払いの場合は別ルール（5倍）。条件はどちらか一方だけをオンにすること。'],
               cond='aeon_ariga10_aeonpay'),
    bonus_rule('aeon_card_thanks_day_bonus', 'イオンカード お客さま感謝デー（5%OFF）',
               '毎月20日・30日にイオングループの対象店舗で支払うと買い物代金が5%OFFになる。200円につき10WAON POINT相当として登録する。',
               'aeon_card', 200, 10, 'waon_point', AEON_THANKS, ['src_aeon_thanks_day', 'src_aeon_card_official'],
               ['毎月20日・30日はお客さま感謝デー。イオングループ対象店舗で買い物代金が5%OFF。',
                'これはポイント進呈ではなく値引き。値引き額を同額の還元として円換算で登録している（200円につき10ポイント＝5%）。',
                '対象はイオン・マックスバリュ・イオンスーパーセンター・サンデー・ビブレ・ザ・ビッグなど。一部対象外店舗・対象外商品あり。',
                '交通系電子マネーでの支払いは対象外。',
                '値引き後の金額に対してポイントが付く場合、実際の合計特典はわずかに下がる。'],
               cond='aeon_thanks_day'),
]

# ===== ウエルシアカード =====
NEW_RULES += [
    base_rule('welcia_card_base', 'ウエルシアカード 基本還元（200円につき1WAON POINT）',
              'イオンマークのカードとして200円（税込）につき1WAON POINT。', 'welcia_card', 200, 1, 'waon_point',
              ['src_aeon_welcia_card', 'src_aeon_point_official'],
              ['ウエルシアカードはイオンマークのカードのため、通常は200円（税込）につき1WAON POINT（0.5%）。',
               'ウエルシアグループの対象店舗では別ルールで1.5%になる。']),
    bonus_rule('welcia_card_aeon_group_bonus', 'ウエルシアカード イオングループ対象店舗の上乗せ（いつでも2倍）',
               'イオングループの対象店舗では200円につき1WAON POINTを上乗せし、合計2ポイント（1.0%）にする。',
               'welcia_card', 200, 1, 'waon_point', AEON_GROUP, AEON_SRC,
               ['イオンマークのカード共通特典。イオングループの対象店舗ならいつでも基本の2倍（1.0%）。'],
               agg='welcia_card_aeon_group_bonus_200'),
    bonus_rule('welcia_card_welcia_group_bonus', 'ウエルシアカード ウエルシアグループの上乗せ（1.5%）',
               'ウエルシアグループの対象店舗でクレジット払いをすると、200円につき2WAON POINTを上乗せし合計3ポイント（1.5%）にする。',
               'welcia_card', 200, 2, 'waon_point', WELCIA_GROUP, WELCIA_SRC,
               ['ウエルシアグループの対象店舗でカード提示1%、クレジット払い1.5%。',
                '基本還元200円1ポイントと合算して200円3ポイント＝1.5%。',
                '対象はウエルシア・ハックドラッグ・金光薬品・とをしや薬局・ダックス・スーパードラッグひまわり・マルエドラッグ・ハッピー・ドラッグ・よどやドラッグ・ふく薬品・コクミン。ウェルパークは対象外。',
                '毎月20日のウエルシアお客さま感謝デーにWAON POINTを使うと1.5倍分になる（計算には反映していない）。']),
    bonus_rule('welcia_card_10th_bonus', 'ウエルシアカード 毎月10日の10%デー',
               '毎月10日にウエルシアグループの対象店舗でクレジット払いをすると、200円につき17WAON POINTを上乗せし合計20ポイント（10%）にする。',
               'welcia_card', 200, 17, 'waon_point', WELCIA_GROUP, WELCIA_SRC,
               ['毎月10日のクレジット払いは200円につき20WAON POINT（10%）。カード提示を併せると最大11%。',
                '基本還元200円1ポイントと合算して200円20ポイント＝10%。',
                '付与は1%分が当月25日、残り9%分が翌月25日。',
                '対象店舗はウエルシアグループの11チェーン。ウェルパークは対象外。'],
               cond='welcia_10th_day'),
]

# ===== dカード =====
NEW_RULES += [
    base_rule('d_card_base', 'dカード 基本還元（100円につき1ポイント）',
              'dカード・dカード（iD）・dカードを支払い設定したd払いで100円（税込）につき1ポイント。',
              'd_card', 100, 1, 'd_point',
              ['src_dcard_official', 'src_dpoint_tokuyaku_about'],
              ['dカード・dカード（iD）・dカードを支払い設定したd払いで100円（税込）につき1ポイント（1.0%）。',
               '2027年1月利用分から一般dカードは200円1ポイント（0.5%）に改定されるため、別ルール（d_card_base_2027）を登録している。',
               '端数処理の公式明記は未確認のため、取引単位で切り捨てを仮定して登録した。'],
              valid_until='2027-01-01'),
    base_rule('d_card_base_2027', 'dカード 基本還元（200円につき1ポイント・2027年1月利用分から）',
              '2027年1月利用分から、一般のdカードは200円（税込）につき1ポイントになる。',
              'd_card', 200, 1, 'd_point',
              ['src_dcard_revision_2027'],
              ['2027年1月利用分から、dカード GOLD U／GOLD／PLATINUM以外の一般dカードは200円1ポイント（0.5%）に引き下げられる。',
               'スマホのタッチ決済は2027年5月利用分から200円2ポイント（1%）。',
               '有効区間は半開区間 [2027-01-01, 無期限)。'],
              valid_from='2027-01-01'),
]
DCARD_TOKUYAKU = [
    ('matsumotokiyoshi', 'マツモトキヨシ', 100, 2),
    ('cocokara_fine', 'ココカラファイン', 100, 2),
    ('kokumin', 'コクミン', 100, 2),
    ('takashimaya', '高島屋', 200, 1),
    ('kinokuniya', '紀伊國屋書店', 100, 1),
    ('maruzen', '丸善', 200, 1),
    ('junku_do', 'ジュンク堂書店', 200, 1),
    ('tower_records', 'タワーレコード', 100, 1),
    ('big_echo', 'カラオケビッグエコー', 100, 2),
    ('golf_me', 'GOLF me!', 100, 4),
    ('club_med', 'クラブメッド', 100, 3),
    ('sakai_hikkoshi', 'サカイ引越センター', 100, 3),
    ('adidas_online', 'アディダス オンラインショップ', 100, 1),
    ('suit_square', 'SUIT SQUARE', 100, 1),
    ('doutor', 'ドトールコーヒーショップ', 100, 3),
    ('excelsior', 'エクセルシオール カフェ', 100, 3),
    ('aoyama_tailor', '洋服の青山', 100, 1),
    ('orix_rentacar', 'オリックスレンタカー', 100, 3),
]
for mid, label, unit, pts in DCARD_TOKUYAKU:
    total = (unit + pts) / unit * 100 / 100 * 100  # 表示用
    NEW_RULES.append(bonus_rule(
        'd_card_tokuyaku_%s' % mid, 'dカード特約店 %s（100円につき+%dポイント）' % (label, pts),
        'dカード特約店の%sで支払うと%sにつき%dポイントを上乗せする。' % (label, '%d円' % unit, pts),
        'd_card', unit, pts, 'd_point', [mid],
        ['src_dcard_official', 'src_dpoint_tokuyaku_about'],
        ['dカード特約店では決済ポイント（1%）に加えて特約店ポイントが上乗せされる。',
         '%sにつき+%dポイントを上乗せとして登録している。' % ('%d円' % unit, pts),
         '対象決済はdカード（Visa/Mastercard）・dカード（iD）・dカードを支払い設定したd払い。',
         'dカード以外のクレジットカードでのiD、d払いタッチ／バーチャルカード、電話料金合算払いのd払いは対象外。',
         '一部対象外の店舗・商品がある。',
         '2027年1月利用分からの基本還元改定後も特約店ポイントは上乗せされる。']))

# ===== PayPayカード =====
NEW_RULES += [
    base_rule('paypay_card_base', 'PayPayカード 基本還元（200円につき2ポイント）',
              'PayPayカードの利用200円（税込）につき2PayPayポイント。', 'paypay_card', 200, 2, 'paypay_point',
              ['src_paypay_card_point'],
              ['200円（税込）につき2PayPayポイント（基本1.0%）。',
               '1ポイント＝1円相当。',
               '端数処理の公式明記は未確認のため、取引単位で切り捨てを仮定して登録した。']),
    bonus_rule('paypay_card_step_bonus', 'PayPayカード 条件達成特典（+0.5%）',
               '200円以上30回かつ10万円以上の利用で0.5%が加算され、合計1.5%になる。',
               'paypay_card', 200, 1, 'paypay_point', [], PAYPAY_SRC,
               ['条件達成特典（200円以上30回＆10万円以上利用）で0.5%が加算され、適用期間は合計最大1.5%。',
                '判定期間と適用期間はPayPayステップの規定による。',
                '基本還元200円2ポイントと合算して200円3ポイント＝1.5%。'],
               cond='paypay_step_achieved'),
    bonus_rule('paypay_card_yahoo_shopping_bonus', 'PayPayカード Yahoo!ショッピングの上乗せ（毎日最大5%）',
               'Yahoo!ショッピングで支払うと、200円につき8PayPayポイントを上乗せし合計10ポイント（5%）にする。',
               'paypay_card', 200, 8, 'paypay_point', ['yahoo_shopping'], PAYPAY_SRC,
               ['Yahoo!ショッピング・LOHACOで毎日最大5%（PayPayステップ1%＋ストアポイント1%＋毎日もらえる3%）。',
                'PayPayアプリ登録と本人確認（eKYC）が必要。',
                '基本還元200円2ポイントと合算して200円10ポイント＝5%。',
                '「毎日もらえる3%」は期間限定ポイントで、付与上限がある（2026-09-05以降は1人あたり2,000円相当）。cap未対応のため計算には反映していない。',
                'LYPプレミアム スタンダードプラン会員はさらに2%加算される（本カタログでは未登録）。'],
               cond='paypay_app_verified'),
    bonus_rule('paypay_card_lohaco_bonus', 'PayPayカード LOHACOの上乗せ（毎日最大5%）',
               'LOHACOで支払うと、200円につき8PayPayポイントを上乗せし合計10ポイント（5%）にする。',
               'paypay_card', 200, 8, 'paypay_point', ['lohaco'], PAYPAY_SRC,
               ['Yahoo!ショッピング・LOHACOで毎日最大5%（PayPayステップ1%＋ストアポイント1%＋毎日もらえる3%）。',
                'PayPayアプリ登録と本人確認（eKYC）が必要。',
                '基本還元200円2ポイントと合算して200円10ポイント＝5%。',
                '付与上限がある。cap未対応のため計算には反映していない。'],
               cond='paypay_app_verified'),
]

for r in NEW_RULES:
    if r['id'] in rby:
        rby[r['id']].update(r)
    else:
        R.append(r)
        rby[r['id']] = r
save('reward_rules.json', rj)

print('merchants=%d categories=%d conditions=%d rules=%d active=%d' % (
    len(M), len(C), len(J), len(R), sum(1 for x in R if x['status'] == 'active')))

# --------------------------------------------------------------------------
# 5. manifest ハッシュ
# --------------------------------------------------------------------------
mp = os.path.join(D, 'catalog_manifest.json')
mf = json.load(open(mp))
mf['catalogVersion'] = VER
for it in mf['items']:
    it['contentHash'] = hashlib.sha256(open(os.path.join(D, it['fileName']), 'rb').read()).hexdigest()
with open(mp, 'w') as fh:
    json.dump(mf, fh, ensure_ascii=False, indent=2)
    fh.write('\n')
print('manifest updated ->', mf['catalogVersion'])

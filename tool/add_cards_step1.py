#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""イオンカード・ウエルシアカード・dカード・PayPayカードをカタログに追加する（D-143）。"""
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
# 1. 出典
# --------------------------------------------------------------------------
sj = load('sources.json')
S = sj['items']
have = {s['id'] for s in S}
tmpl = [s for s in S if s['id'] == 'src_smbc_vpoint_up_program'][0]

NEW_SRC = {
    'src_aeon_card_official': ('イオンカード（WAON一体型）公式', 'https://www.aeon.co.jp/card/lineup/aeon/', 'イオンクレジットサービス株式会社'),
    'src_aeon_point_official': ('WAON POINT｜イオンカード', 'https://www.aeon.co.jp/point/', 'イオンクレジットサービス株式会社'),
    'src_aeon_waonpoint': ('WAON POINTのため方・つかい方', 'https://www.aeon.co.jp/point/waonpoint/', 'イオンクレジットサービス株式会社'),
    'src_aeon_anytime_double': ('イオングループ対象店舗ならいつでもWAON POINT基本の2倍', 'https://www.aeon.co.jp/point/save/anytime/', 'イオンクレジットサービス株式会社'),
    'src_aeon_ariga10': ('ありが10デー｜お得情報 優待・特典', 'https://www.aeonretail.jp/campaign/ariga10/', 'イオンリテール株式会社'),
    'src_aeon_thanks_day': ('お客さま感謝デー｜イオンカード', 'https://www.aeon.co.jp/merit/thanks_day/', 'イオンクレジットサービス株式会社'),
    'src_aeon_welcia_card': ('ウエルシアカードのご案内', 'https://www.aeon.co.jp/card/lp/welciacard/', 'イオンクレジットサービス株式会社'),
    'src_dcard_official': ('dカード特約店｜dポイントがさらにたまる', 'https://dcard.docomo.ne.jp/st/dpoint_tokuyaku/index.html', '株式会社NTTドコモ'),
    'src_dpoint_tokuyaku_about': ('dカード特約店とは｜dポイントクラブ', 'https://dpoint.docomo.ne.jp/store/dcard_tokuyaku/index.html', '株式会社NTTドコモ'),
    'src_dcard_revision_2027': ('ドコモ「dカード」還元率が0.5%へ半減、使わないと年会費1650円', 'https://k-tai.watch.impress.co.jp/docs/news/2137201.html', '株式会社インプレス'),
    'src_paypay_card_point': ('カード利用特典（PayPayポイント）', 'https://www.paypay-card.co.jp/service/benefit/point/', 'PayPayカード株式会社'),
    'src_paypay_step': ('PayPayステップ', 'https://paypay.ne.jp/event/paypaystep/', 'PayPay株式会社'),
}
for sid, (title, url, pub) in NEW_SRC.items():
    if sid in have:
        it = [s for s in S if s['id'] == sid][0]
    else:
        it = copy.deepcopy(tmpl)
        S.append(it)
    it.update({'id': sid, 'title': title, 'url': url, 'publisher': pub,
               'lastVerifiedAt': TODAY, 'accessStatus': 'accessible'})
save('sources.json', sj)

# --------------------------------------------------------------------------
# 2. ポイントプログラム
# --------------------------------------------------------------------------
pj = load('point_programs.json')
P = pj['items']
pids = {p['id'] for p in P}
ptmpl = [p for p in P if p['id'] == 'j_point'][0]
NEW_PROGRAMS = [
    ('waon_point', 'WAON POINT', 'イオンクレジットサービス株式会社',
     ['イオンマークのカード払い200円（税込）につき1ポイント。', '1ポイント＝1円から対象店舗でのお支払いに使える。', 'イオングループ各店・WAON POINT加盟店で利用可。'],
     ['src_aeon_point_official', 'src_aeon_waonpoint']),
    ('d_point', 'dポイント', '株式会社NTTドコモ',
     ['dカードの利用100円（税込）につき1ポイント。', '1ポイント＝1円相当として利用できる。', '2027年1月利用分から一般dカードは200円1ポイントに改定予定。'],
     ['src_dcard_official', 'src_dcard_revision_2027']),
    ('paypay_point', 'PayPayポイント', 'PayPayカード株式会社',
     ['PayPayカードの利用200円（税込）につき2ポイント（基本1.0%）。', '1ポイント＝1円相当。', 'Yahoo!ショッピング・LOHACOでは毎日最大5%が付与される。'],
     ['src_paypay_card_point']),
]
for pid, name, issuer, notes, srcs in NEW_PROGRAMS:
    if pid in pids:
        continue
    p = copy.deepcopy(ptmpl)
    p.update({'id': pid, 'name': name, 'issuerName': issuer,
              'unitName': 'pt',
              'valueDefinition': {'valueType': 'fixed', 'yenPerPoint': {'numerator': 1, 'denominator': 1}},
              'expiration': {'expirationType': 'unknown'},
              'status': 'active', 'sourceIds': srcs, 'lastVerifiedAt': TODAY,
              'notes': notes})
    P.append(p)
save('point_programs.json', pj)

# --------------------------------------------------------------------------
# 3. カード（payment_instruments）
# --------------------------------------------------------------------------
ij = load('payment_instruments.json')
I = ij['items']
iids = {i['id'] for i in I}
itmpl = [i for i in I if i['id'] == 'mufg_card'][0]
NEW_CARDS = [
    dict(id='aeon_card', name='イオンカード（WAON一体型）', shortName='イオンカード',
         instrumentType='creditCard', issuerName='イオンクレジットサービス株式会社',
         tags=['credit_card', 'no_annual_fee', 'waon'],
         claims=['イオングループ対象店舗でいつでも基本の2倍（1.0%）',
                 '毎月20日・30日はお客さま感謝デーで5%OFF',
                 '毎月10日のありが10デーは5倍（AEON Payは10倍）'],
         srcs=['src_aeon_card_official', 'src_aeon_point_official', 'src_aeon_anytime_double', 'src_aeon_ariga10', 'src_aeon_thanks_day'],
         notes=['イオンマークのカード払い200円（税込）につき1WAON POINT（0.5%）。イオングループの対象店舗では200円につき2WAON POINT（1.0%）。',
                '電子マネーWAONでの支払いも同率（イオングループ対象店舗で200円2WAON POINT）。',
                'AEON Payのスマホ決済も「いつでも2倍」の対象。AEON Payを除くQRコード・バーコード決済は対象外。',
                'イオングループ対象店舗以外（Visa/JCB/Mastercard加盟店）は200円1WAON POINT。',
                'お客さま感謝デー（毎月20日・30日）は買い物代金が5%OFFになる「値引き」。ポイント進呈ではないが、アプリでは同額の還元として円換算で表示する。',
                'ありが10デー（毎月10日）は本州（東北を除く）・四国のイオン／イオンスタイル直営売場が対象。イオンカード払いで5倍、AEON Payのスマホ決済で10倍。',
                'Wポイントデー（毎月1回のAEON Pay／カード利用でポイント2倍）は2026-12-10をもって終了するため登録しない。',
                'ポイント付与上限は公式に明記がなく未確認。cap未対応のため計算には反映していない。']),
    dict(id='welcia_card', name='ウエルシアカード', shortName='ウエルシア',
         instrumentType='creditCard', issuerName='イオンクレジットサービス株式会社',
         tags=['credit_card', 'no_annual_fee', 'waon'],
         claims=['ウエルシアグループ対象店舗でクレジット払い1.5%',
                 '毎月10日はカード提示1%＋クレジット払い10%で最大11%'],
         srcs=['src_aeon_welcia_card', 'src_aeon_point_official', 'src_aeon_anytime_double'],
         notes=['ウエルシアグループ対象店舗でカード提示1%、クレジット払い1.5%。',
                '毎月10日はカード提示1%＋クレジット払い10%で合計最大11%（公式LPの記載）。クレジット払いのみの場合は10%。',
                'イオンマークのカードのため、イオングループ対象店舗では「いつでも基本の2倍」（1.0%）も適用される。',
                '貯まるのはWAON POINT。毎月20日のウエルシアお客さま感謝デーに使うと1.5倍分（10,000ポイントで15,000円分）になる。',
                '対象店舗はウエルシア・ハックドラッグ・金光薬品・とをしや薬局・ダックス・スーパードラッグひまわり・マルエドラッグ・ハッピー・ドラッグ・よどやドラッグ・ふく薬品・コクミン。ウェルパークは対象外。',
                '毎月10日のクレジット10%の付与は、1%分が当月25日、残り9%分が翌月25日。',
                '付与上限は公式に明記がなく未確認。cap未対応のため計算には反映していない。']),
    dict(id='d_card', name='dカード', shortName='dカード',
         instrumentType='creditCard', issuerName='株式会社NTTドコモ',
         tags=['credit_card', 'no_annual_fee'],
         claims=['基本1.0%（100円につき1ポイント）',
                 'dカード特約店でさらにポイントがたまる',
                 '2027年1月利用分から基本0.5%相当に改定予定'],
         srcs=['src_dcard_official', 'src_dpoint_tokuyaku_about', 'src_dcard_revision_2027'],
         notes=['dカード（Visa/Mastercard）・dカード（iD）・dカードを支払い設定したd払いで100円（税込）につき1ポイント（1.0%）。',
                'dカード特約店では決済ポイント（1%）に加えて特約店ポイントが上乗せされる。',
                '2027年1月利用分から、dカード GOLD U／GOLD／PLATINUM以外の一般dカードは200円1ポイント（0.5%）に改定予定。スマホのタッチ決済は2027年5月利用分から200円2ポイント（1%）。',
                '前年度に一度も利用がない場合は年会費1,650円（2027年1月以降の利用有無に基づき2028年2月請求分から）。',
                'dカード以外のクレジットカードでのiD、dカード以外を支払い設定したd払い、電話料金合算払いのd払い、d払いタッチ／バーチャルカードは特約店ポイントの対象外。',
                '端数処理は公式に明記がなく未確認。取引単位で切り捨てを仮定して登録した。',
                '2026年12月以降にポイント還元率・進呈条件・年会費の見直しが予告されている。詳細が公表されたら改定する。']),
    dict(id='paypay_card', name='PayPayカード', shortName='PayPay',
         instrumentType='creditCard', issuerName='PayPayカード株式会社',
         tags=['credit_card', 'no_annual_fee'],
         claims=['基本1.0%（200円につき2ポイント）',
                 '条件達成で+0.5%（最大1.5%）',
                 'Yahoo!ショッピング・LOHACOで毎日最大5%'],
         srcs=['src_paypay_card_point', 'src_paypay_step'],
         notes=['200円（税込）につき2PayPayポイント（基本1.0%）。',
                '条件達成特典（200円以上30回＆10万円以上利用）で0.5%が加算され、適用期間は合計最大1.5%。',
                'Yahoo!ショッピング・LOHACOでは毎日最大5%（PayPayステップ1%＋ストアポイント1%＋毎日もらえる3%）。PayPayアプリ登録と本人確認が必要。',
                'LYPプレミアム スタンダードプラン会員はさらに2%が加算され最大7%。本カタログには登録していない。',
                'PayPayカード ゴールドの+0.5%特典は2026-06-02に終了した。',
                '「毎日もらえる3%」は期間限定ポイントで、付与上限がある（2026-09-05以降は1人あたり2,000円相当）。cap未対応のため計算には反映していない。']),
]
for spec in NEW_CARDS:
    if spec['id'] in iids:
        continue
    card = copy.deepcopy(itmpl)
    card.update({
        'id': spec['id'], 'name': spec['name'], 'shortName': spec['shortName'],
        'instrumentType': spec['instrumentType'], 'issuerName': spec['issuerName'],
        'partnerInstitutionName': None,
        'annualFee': 0, 'validFrom': TODAY, 'validUntilExclusive': None,
        'status': 'active', 'sourceIds': spec['srcs'], 'lastVerifiedAt': TODAY,
        'displayClaims': spec['claims'], 'tags': spec['tags'], 'notes': spec['notes'],
    })
    I.append(card)
save('payment_instruments.json', ij)

print('cards=%d programs=%d sources=%d' % (len(I), len(P), len(S)))

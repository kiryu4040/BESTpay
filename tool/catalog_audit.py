"""BESTpay catalog integrity audit (read-only)."""
import json, re, sys, itertools
from collections import defaultdict

D = 'assets/data/'
def load(f): return json.load(open(D + f, encoding='utf-8'))

rules = load('reward_rules.json')['items']
merchants = load('merchants.json')['items']
cats = load('merchant_categories.json')['items']
conds = load('condition_definitions.json')['items']
progs = load('point_programs.json')['items']
insts = load('payment_instruments.json')['items']
srcs = load('sources.json')['items']

ID_RE = re.compile(r'^[a-z][a-z0-9_]{2,79}$')
E = []   # errors
W = []   # warnings
I = []   # info

def err(m): E.append(m)
def warn(m): W.append(m)

# ---------- 1. ID uniqueness & format ----------
seen = defaultdict(list)
for label, items in [('rule', rules), ('merchant', merchants), ('category', cats),
                     ('condition', conds), ('pointProgram', progs), ('instrument', insts), ('source', srcs)]:
    for it in items:
        i = it.get('id')
        seen[i].append(label)
        if not i or not ID_RE.match(i):
            err(f'ID形式違反 [{label}] {i!r}')
for i, labels in seen.items():
    if len(labels) > 1:
        err(f'ID重複: {i} -> {labels}')

ids = {k: {x['id'] for x in v} for k, v in
       [('rule', rules), ('merchant', merchants), ('category', cats), ('condition', conds),
        ('pointProgram', progs), ('instrument', insts), ('source', srcs)]}

# ---------- 2. referential integrity (deep scan of every string) ----------
def walk(o, path, out):
    if isinstance(o, dict):
        for k, v in o.items(): walk(v, f'{path}.{k}', out)
    elif isinstance(o, list):
        for n, v in enumerate(o): walk(v, f'{path}[{n}]', out)
    elif isinstance(o, str): out.append((path, o))

def deep_refs(items, label):
    for it in items:
        strs = []; walk(it, label + ':' + str(it.get('id')), strs)
        for path, val in strs:
            if val in ids['merchant'] and not path.endswith('merchantIds') and 'merchantGroupIds' not in path:
                pass  # same-name collision check handled below
            for ns, key in [('instrument', 'instrumentIds'), ('merchant', 'merchantIds'),
                            ('category', 'categoryIds'), ('condition', 'conditionIds'),
                            ('pointProgram', 'outputPointProgramId'), ('source', 'sourceIds')]:
                pass
deep_refs(rules, 'rule')

def ref_check(value, namespace, where):
    if value and value not in ids[namespace]:
        err(f'参照切れ [{namespace}] {value} <- {where}')

for r in rules:
    rid = r['id']; w = f'rule:{rid}'
    for ns, field in [('instrument', 'instrumentIds'), ('merchant', 'merchantIds'),
                      ('category', 'categoryIds'), ('source', 'sourceIds')]:
        for v in (r.get('selectors', {}).get(field) or []): ref_check(v, ns, w + '.selectors.' + field)
        for v in (r.get('exclusions', {}).get(field) or []): ref_check(v, ns, w + '.exclusions.' + field)
    for v in (r.get('selectors', {}).get('merchantGroupIds') or []): ref_check(v, 'merchantGroup', w) if 'merchantGroup' in ids else None
    ref_check(r.get('outputPointProgramId'), 'pointProgram', w + '.outputPointProgramId')
    for v in (r.get('stacking', {}).get('replacesRuleIds') or []): ref_check(v, 'rule', w + '.replacesRuleIds')
    for v in (r.get('stacking', {}).get('suppressesRuleIds') or []): ref_check(v, 'rule', w + '.suppressesRuleIds')
    strs = []; walk(r.get('conditionExpression'), w + '.conditionExpression', strs)
    for path, v in strs:
        if v in ids['condition'] or v in ids['merchant'] or v in ids['category']:
            continue
    def scan_conds(o, path):
        if isinstance(o, dict):
            for k, v in o.items():
                if k == 'conditionId' and isinstance(v, str): ref_check(v, 'condition', path)
                scan_conds(v, f'{path}.{k}')
        elif isinstance(o, list):
            for n, v in enumerate(o): scan_conds(v, f'{path}[{n}]')
    scan_conds(r.get('conditionExpression'), w)

for m in merchants:
    for v in (m.get('merchantGroupIds') or []): ref_check(v, 'merchantGroup', f'merchant:{m["id"]}') if 'merchantGroup' in ids else None
    for v in (m.get('categoryIds') or []): ref_check(v, 'category', f'merchant:{m["id"]}')
    for v in (m.get('sourceIds') or []): ref_check(v, 'source', f'merchant:{m["id"]}')
for c in cats:
    for v in (c.get('sourceIds') or []): ref_check(v, 'source', f'category:{c["id"]}')
    ref_check(c.get('parentCategoryId'), 'category', f'category:{c["id"]}')
for cd in conds:
    for v in (cd.get('sourceIds') or []): ref_check(v, 'source', f'condition:{cd["id"]}')
for p in progs:
    for v in (p.get('sourceIds') or []): ref_check(v, 'source', f'pointProgram:{p["id"]}')
for i in insts:
    for v in (i.get('sourceIds') or []): ref_check(v, 'source', f'instrument:{i["id"]}')
    for v in (i.get('availableBrandIds') or []): ref_check(v, 'brand', f'instrument:{i["id"]}') if 'brand' in ids else None

# ---------- 3. rule hygiene ----------
for r in rules:
    rid = r['id']; w = f'rule:{rid}'
    if r.get('cap') not in (None, {}): warn(f'cap非null（エンジン未対応） {rid}: {r.get("cap")}')
    agg = r.get('aggregation') or {}
    scope = agg.get('scope')
    if scope and scope != 'transaction':
        if not agg.get('aggregationKey'): err(f'期間集計なのに aggregationKey 無し {rid}')
        if not agg.get('incrementalAward'): err(f'期間集計なのに incrementalAward が真でない {rid}')
    txt = json.dumps(r, ensure_ascii=False)
    if re.search(r'毎月\d+日|毎月第\d|◯日|〇日', txt):
        warn(f'日付条件の記述あり（エンジンは日付で分岐不可） {rid}')
    if not r.get('sourceIds'): warn(f'sourceIds が空 {rid}')
    if not r.get('lastVerifiedAt'): warn(f'lastVerifiedAt が空 {rid}')

# aggregationKey collision per instrument (D-108: 分ける)
key_map = defaultdict(list)
for r in rules:
    agg = r.get('aggregation') or {}
    if agg.get('scope') and agg.get('scope') != 'transaction' and agg.get('aggregationKey'):
        for inst in (r.get('selectors', {}).get('instrumentIds') or ['<global>']):
            key_map[(inst, agg['scope'], agg['aggregationKey'])].append(r['id'])
for k, v in key_map.items():
    if len(v) > 1:
        I.append(f'同一集計キーを共有: {k} -> {v}')

# ---------- 4. coverage matrix ----------
def active(it): return it.get('status') == 'active'
act_rules = [r for r in rules if active(r)]
act_insts = [i for i in insts if active(i)]

def rule_matches(r, inst, m):
    sel = r.get('selectors') or {}
    if inst['id'] not in (sel.get('instrumentIds') or []): return False
    ex = r.get('exclusions') or {}
    if inst['id'] in (ex.get('instrumentIds') or []): return False
    if m['id'] in (ex.get('merchantIds') or []): return False
    mids, gids, cids = sel.get('merchantIds') or [], sel.get('merchantGroupIds') or [], sel.get('categoryIds') or []
    if not mids and not gids and not cids: return True
    if m['id'] in mids: return True
    if set(gids) & set(m.get('merchantGroupIds') or []): return True
    if set(cids) & set(m.get('categoryIds') or []): return True
    return False

cov = {}
for m in merchants:
    if not active(m): continue
    cards = [i['id'] for i in act_insts if any(rule_matches(r, i, m) for r in act_rules)]
    cov[m['id']] = cards

print('=== 監査結果 ===')
print(f'ルール {len(rules)} (active {len(act_rules)}) / 店舗 {len(merchants)} / カテゴリ {len(cats)} / 条件 {len(conds)} / ポイント {len(progs)} / カード {len(insts)} / 出典 {len(srcs)}')
print()
print(f'--- エラー {len(E)} 件 ---')
for e in E: print(' E:', e)
print(f'--- 警告 {len(W)} 件 ---')
for w in W: print(' W:', w)
print(f'--- 情報 {len(I)} 件 ---')
for i in I: print(' I:', i)
print()
print('--- カード別カバレッジ ---')
for i in act_insts:
    n = sum(1 for m, cs in cov.items() if i['id'] in cs)
    print(f'  {i["id"]:<28} {n:>3}店舗')
print()
print('--- 比較可能カードが少ない店舗（3枚以下） ---')
for m, cs in sorted(cov.items(), key=lambda x: len(x[1])):
    if len(cs) <= 3: print(f'  {m:<28} {len(cs)}枚 {cs}')
print()
print('--- どのカードも比較できない店舗 ---')
none = [m for m, cs in cov.items() if not cs]
print('  ', none or 'なし')
print()
print('--- 未使用の条件定義 ---')
used = set()
def collect_cond(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == 'conditionId' and isinstance(v, str): used.add(v)
            collect_cond(v)
    elif isinstance(o, list):
        for v in o: collect_cond(v)
for r in rules: collect_cond(r.get('conditionExpression'))
print('  ', sorted(ids['condition'] - used) or 'なし')
print()
print('--- 未参照の出典 ---')
used_src = set()
for coll in (rules, merchants, cats, conds, progs, insts):
    for it in coll: used_src |= set(it.get('sourceIds') or [])
print('  ', sorted(ids['source'] - used_src) or 'なし')
print()
print('--- 店舗IDごとの登録ルール数（上位/下位） ---')
mc = defaultdict(int)
for r in act_rules:
    for mid in (r.get('selectors', {}).get('merchantIds') or []): mc[mid] += 1
print('  ルールが1本も無い店舗:', sorted(set(cov) - set(mc)) or 'なし')

# ===== 追加検査（D-154 / 他AI監査 AUD-06 の指摘に対応）=====
import os as _os
import sys as _sys

_errors = list(E)


def _load_optional(name):
    path = D + name
    if not _os.path.exists(path):
        return None
    return json.load(open(path, encoding='utf-8')).get('items', [])


_groups = _load_optional('merchant_groups.json') or []
_brands = _load_optional('brands.json')
_group_ids = {g['id'] for g in _groups}
_brand_ids = {b['id'] for b in _brands} if _brands is not None else None

# 1) 店舗の merchantGroupIds
for _m in merchants:
    for _g in (_m.get('merchantGroupIds') or []):
        if _g not in _group_ids:
            _errors.append('参照切れ [merchantGroup] %s <- merchant:%s' % (_g, _m['id']))

# 2) ルールの merchantGroupIds / brandIds
for _r in rules:
    for _g in ((_r.get('selectors') or {}).get('merchantGroupIds') or []):
        if _g not in _group_ids:
            _errors.append('参照切れ [merchantGroup] %s <- rule:%s' % (_g, _r['id']))
    for _b in ((_r.get('selectors') or {}).get('brandIds') or []):
        if _brand_ids is not None and _b not in _brand_ids:
            _errors.append('参照切れ [brand] %s <- rule:%s' % (_b, _r['id']))

# 3) ルール直下の sourceIds
for _r in rules:
    for _sid in (_r.get('sourceIds') or []):
        if _sid not in ids['source']:
            _errors.append('参照切れ [source] %s <- rule:%s' % (_sid, _r['id']))

# 4) カードの brandIds
for _i in insts:
    for _b in (_i.get('availableBrandIds') or []):
        if _brand_ids is not None and _b not in _brand_ids:
            _errors.append('参照切れ [brand] %s <- instrument:%s' % (_b, _i['id']))

print()
print('=== 追加検査 ===')
print('  merchantGroup参照:', len(_group_ids), 'グループ定義')
print('  brand定義:', 'なし（ファイル未作成のため検査スキップ）' if _brand_ids is None else '%d件' % len(_brand_ids))
print('  エラー合計: %d件' % len(_errors))
for _e in _errors:
    print('   E:', _e)

if _errors:
    _sys.exit(1)

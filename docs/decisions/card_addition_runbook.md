# カード1枚を追加する手順（唯一の手順）

新しいカード・QR決済・ポイントをBESTpay v2へ追加するときは、必ずこの6段を踏みます。
**この手順を踏む限り、アプリ本体のDartコードを変更する必要はありません。**

対象は `assets/data/` 配下のJSONカタログです。スキーマは `schemas/` にあり、
`tool/` の検証器と `.github/workflows/schema-validation.yml` が自動で検査します。

---

## 第1段：公式情報を集める

カード会社・銀行・決済事業者の**公式**情報のみを使います。

優先順位（資料 第17章）:

1. 公式規約
2. 公式FAQ
3. 公式商品ページ
4. 公式キャンペーンページ
5. 公式ニュースリリース
6. 公式アプリ内案内
7. 信頼できる第三者記事
8. ユーザー報告

**7・8しか無い制度は登録できません**（裁定 CR-015）。登録する場合は `status: draft` とし、
確定ランキングには使いません。

記録するもの:

- URL、発行元、公開日、確認日、種別（`sourceType`）、信頼度
- 還元率・計算単位・集計期間・端数処理・上限・対象外・達成条件
- 制度の開始日と終了日（**終了日未定は null**）

---

## 第2段：決済手段を登録する

`assets/data/payment_instruments.json` に1件追加します。

- `id` — 形式 `^[a-z][a-z0-9_]{2,79}$`。**後から絶対に変えない**（D-64）
- `name` / `shortName` / `issuer`
- `instrumentType` — creditCard / debitCard / qrPayment / electronicMoney など
- `availableBrands`
- `annualFeeYen`
- `supportedRouteIds` — 第3段の決済経路IDを参照
- `sourceIds` — 第1段の情報源IDを参照

同じ決済手段でも**支払いモード**（credit / debit / pointPay / addedCard）を区別する場合は
`payment_modes.json` にも登録します。

利用可能な**決済経路**（physicalCard / mobileContactless / onlineCard / qrCode など）は
`payment_routes.json` を参照し、不足していれば追加します。

---

## 第3段：還元ルールを分解して登録する

`assets/data/reward_rules.json` に追加します。**ここが本題です。**

「1.5%」のような率をそのまま書いてはいけません。次のように分解します。

| 分解する要素 | 例 |
|---|---|
| 計算単位 | `amountUnitYen: 200`, `pointsPerUnit: 1` |
| 集計範囲 | `aggregationScope`: transaction / daily / monthly / billingCycle / annual |
| 端数処理 | `roundingMethod`: floor / ceiling / towardZero / halfAwayFromZero / halfToEven / exact |
| 率を使う場合 | `numerator` / `denominator` の既約分数（小数にしない） |
| 有効期間 | `validFrom` ≦ 判定日 ＜ `validUntilExclusive` |
| 日付基準 | `dateBasis`: transactionDate / postingDate / settlementDataReceivedDate / billingDate / entryDate / campaignRegistrationDate / periodEndDate |
| 情報源 | `sourceIds`（必須） |
| 状態 | `status`: active / draft / suspended / deprecated / ended |

**必ず分離するもの:**

- 基本還元と上乗せ還元（別ルール）
- 年間ボーナスと通常還元（別ルール。通常0.5%に年間1万ptを足して「1.5%」と書かない — 裁定 CR-018）
- 制度改定の前後（上書きせず2本のルールにする — CR-014）
- 月間合算型は月間の増分として計算する（`floor((P+A)/U) - floor(P/U)`）
- 広告上の最大還元率は `displayClaim` として分離（計算値にしない — CR-013）

---

## 第4段：対象外取引と条件を登録する

- **対象外**はカテゴリの推測だけで確定させない。加盟店・取引タグ・公式分類の一致を使う（CR-034）。
  カテゴリ一致だけの場合は `estimated` とする。
- **条件**（口座振替設定、アプリ登録、エントリー等）は `condition_definitions.json` に定義し、
  ルールから参照する。未入力の条件は `unknown` とし、達成済みとして扱わない（D-50）。
- 対象店舗の上乗せは、決済経路（物理カード / iD / 差し込み / 磁気 と スマホタッチ決済）を
  別selectorで区別する（D-73）。
- 店舗が絡む場合は `merchants.json` / `merchant_groups.json` / `merchant_categories.json` に登録する。
  対象外となる店舗パターン（商業施設内店舗、サービスエリア店舗、ネット注文等）も保持する。
- チャージ関係は `funding_relations.json` に登録し、**チャージ可否**と**ポイント付与可否**を
  別フィールドで持つ（D-74）。
- 提示ポイント（Ponta / dポイント / 楽天ポイント / Vポイント）はカード還元と**別の加算要素**
  として登録する（D-75）。

---

## 第5段：検証してテストを足す

1. スキーマ検証を通す（`schemas/catalog/` に適合。`additionalProperties: false` に注意）
2. 参照整合性を確認（参照先IDが存在するか。切れがあれば `error`）
3. **そのカードの代表ケースをテストとして追加する**
   - 端数処理（例：150円で何ポイントか）
   - 月間合算の増分（未入力時は推定になるか）
   - 上限到達（上限値とその手前）
   - 対象外（対象外取引で0になるか）
   - 制度の境界日（改定日の前日と当日）
   - 条件が `unknown` のとき確定値に混ざらないか
4. テストを実行し、既存57本と合わせて全件成功を確認する

ここを省くと、カードが増えるほど壊れたことに気づけなくなります。

---

## 第6段：マニフェストを更新する

`assets/data/catalog_manifest.json` の `catalogVersion` を更新します。

- 形式：`YYYY.MM.DD.REVISION`（例 `2026.09.27.1`）。**辞書順で比較しない**（年/月/日/revisionに分解）
- 各ファイルの `contentHash` を更新
- `disabledRuleIds` に緊急停止するルールがあれば追加

最後に GitHub へ push します。pushすると `build-apk.yml` が自動でAPKをビルドするので、
Actionsのartifactからスマホへ入れ直せば新しいカードが使えます。

---

## よくある失敗

| 失敗 | 何が起きるか | 正しい扱い |
|---|---|---|
| 「2%」とだけ書く | 端数処理を再現できず、150円の計算が狂う | 計算単位（200円につき1pt等）で書く |
| 年間ボーナスを基本還元に足す | 年間平均還元率が常に高く出る | 別ルールに分ける |
| 制度改定で旧ルールを上書きする | 過去の日付で計算したときに誤る | 2本のルールを半開区間で並べる |
| 日付基準を transactionDate で代用する | V NEOBANK等の境界で誤る | `settlementDataReceivedDate` を指定する |
| まとめサイトだけで登録する | 誤情報が確定値として表示される | `status: draft` にする |
| IDを後から変える | 保存済みユーザーデータが参照切れになる | `id_migrations.json` を経由する |

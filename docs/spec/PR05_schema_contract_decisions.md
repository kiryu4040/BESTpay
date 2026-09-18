# PR-05 JSON Schema契約 設計判断

文書ID：BP-PR05-SCHEMA-DECISIONS-001
文書バージョン：1.0.0
ステータス：active
対象：BESTpay v2 JSON Schema Draft 2020-12

## 1. 目的

本書は、統合チェックポイントでファイル名または概念だけが定義され、
JSON上の詳細構造が確定していない項目について、PR-05で採用する
最小契約を記録する。

本書は商品別の実データ、計算ロジック、SQLite構造、画面仕様を
確定するものではない。

## 2. 共通原則

- JSON Schema Draft 2020-12を使用する。
- Schema IDは`urn:bestpay:schema:<name>:1.0.0`とする。
- objectには原則として`additionalProperties: false`を指定する。
- 必須フィールドは`required`へ明記する。
- IDはStableId Schemaを参照する。
- 日付はdate Schema、日時はtimestamp Schemaを参照する。
- 金額とポイント数はintegerで保存する。
- 率はRationalで保存する。
- enum indexは保存しない。
- 未確定の列挙値を推測で閉じたenumにしない。
- 参照整合性、日付の前後関係、循環参照は別Validatorで検査する。

## 3. ConditionExpression

保存形式は次のノード種別を使用する。

- all
- any
- not
- condition
- comparison

`all`と`any`は`children`を持つ。
`not`は単一の`child`を持つ。
`condition`は`conditionId`を持つ。
`comparison`は`conditionId`、`comparisonOperator`、`value`を持つ。

最大深度10および最大ノード数100は、Schema適合確認に加えて
専用Validatorでも検査する。

ConditionExpressionの評価ロジックはPR-07の対象とする。

## 4. SelectorSet

SelectorSetは次の10配列を常に保持する。

- instrumentIds
- modeIds
- routeIds
- fundingRelationIds
- merchantIds
- merchantGroupIds
- categoryIds
- brandIds
- locationIds
- transactionTags

空配列は、その軸に制限がないことを表す。

## 5. SourceReference

SourceReferenceはSourceレコードのIDを表すStableIdとする。

情報源のprimary判定、参照先の存在確認、変更状態の検査は
Catalog Integrity Validatorで行う。

## 6. Merchant系Schema

統合チェックポイントにはMerchant系Schemaの正式なフィールド一覧がない。
PR-05では次の最小構造を採用する。

### MerchantGroup

- id
- name
- description
- status
- sourceIds
- notes

### Merchant

- id
- name
- merchantGroupIds
- categoryIds
- locationIds
- status
- sourceIds
- notes

### MerchantCategory

- id
- name
- parentCategoryId
- status
- sourceIds
- notes

`parentCategoryId`は最上位カテゴリの場合にnullを許可する。

Merchantとカテゴリの一致だけでは店舗固有特典をconfirmedにしない。
この判定はSchemaではなく計算・整合性検証側で行う。

## 7. ID移行Schema

ID移行は次の種別を使用する。

- rename
- merge
- split
- remove

共通フィールドは次とする。

- id
- entityType
- migrationType
- fromIds
- toIds
- evidenceSourceIds
- needsReview
- effectiveFrom
- notes

`fromIds`は移行前ID、`toIds`は移行後IDを表す。
`evidenceSourceIds`は根拠となるSourceレコードを表す。
情報源IDと移行対象IDに同じフィールド名を使用しない。

- renameはfromIds 1件、toIds 1件とする。
- mergeはfromIds 2件以上、toIds 1件とする。
- splitはfromIds 1件、toIds 2件以上とする。
- removeはfromIds 1件、toIds 0件とする。
- splitとremoveはneedsReviewをtrueとする。
- 不明なIDを黙って削除しない。

## 8. 確定した列挙値とPointProgram方針

CatalogItemStatusは次の8値とする。

- draft
- unverified
- active
- inactive
- deprecated
- superseded
- historical
- archived

Source.accessStatusは次の4値とする。

- accessible
- changed
- unavailable
- archived

Source.reliabilityは次の4値とする。

- primary
- secondary
- userReported
- unverified

PointProgram.valueDefinitionのvalueTypeは次の3値とする。

- fixed
- variable
- unset

PointProgram.expirationのexpirationTypeは次の4値とする。

- none
- fixedDate
- durationMonths
- unknown

fixedの場合だけyenPerPointを必須とする。
fixedDateの場合だけexpiresOnを必須とする。
durationMonthsの場合だけmonthsを必須とする。

未確定のinstrumentType、routeType、relationType、
ConditionDefinition.valueType、scope、sensitivityは、
PR-05では非空文字列として扱う。

## 9. Catalog Manifest

商品カタログ用のcatalog_manifest.jsonは、
文書管理用のdocs/spec/spec_manifest.jsonとは別の契約とする。

Catalog Manifestのルートは次のフィールドを持つ。

- schemaVersion
- catalogVersion
- generatedAt
- items

itemsには、catalog_manifest.json自身を除く12個の
カタログファイルを登録する。

各項目は次のフィールドを持つ。

- fileName
- schemaId
- contentHash
- required

12ファイルの存在、fileNameの一意性、fileNameとschemaIdの対応、
実ファイルとcontentHashの一致はCatalog Integrity Validatorで検査する。

## 10. OwnedInstrumentとBackup

OwnedInstrumentは次のフィールドを持つ。

- instrumentId
- enabled
- selectedModeIds
- selectedRouteIds
- acquiredOn
- nickname
- createdAt
- updatedAt
- notes

selectedModeIdsとselectedRouteIdsの空配列は、
利用可能なすべてのモードまたは経路を意味する。
acquiredOnとnicknameは未設定時にnullを許可する。
認証情報やカード番号は保存しない。

BESTpay v2バックアップは次のフィールドを持つ。

- formatId
- schemaVersion
- appVersion
- catalogVersion
- exportedAt
- ownedInstruments
- conditionStates
- pointValues
- usagePeriodStates
- favorites
- transactionRecords

formatIdはbestpay-v2-backup、schemaVersionは1.0.0とする。
各データ配列は空の場合も省略しない。
取引履歴保存が無効な場合、transactionRecordsは空配列とする。

PR-05はv2バックアップのJSON契約のみを定義する。
既存v1バックアップ形式および復元処理は変更しない。

## 11. PR-05の非対象

次はPR-05で実装しない。

- 商品別の実カタログデータ
- ConditionExpression評価エンジン
- Catalog Loaderの本番接続
- SQLite Schema変更
- 既存バックアップ形式の変更
- UI変更
- 現行計算経路の変更

## 12. Catalog file root contracts

The twelve catalog data schemas validate complete catalog files rather than
standalone item objects. Each catalog file requires `schemaVersion`,
`catalogVersion`, `generatedAt`, and `items`. The item contract is stored in
`$defs.catalogItem`, and `items.items` refers to that definition.

`RewardRule.timezone` is fixed to `Asia/Tokyo`.

For ID migration cardinality:

- `rename`: one source ID to one destination ID
- `merge`: two or more source IDs to one destination ID
- `split`: one source ID to two or more destination IDs
- `remove`: one source ID to no destination IDs

Catalog Manifest completeness, file-name uniqueness, file-to-schema mapping,
and SHA-256 verification require custom validation.

ConditionExpression maximum depth 10 and maximum node count 100 require custom
validation.

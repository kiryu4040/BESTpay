# PR-06 Catalog Loader and Integrity Validation Decisions

文書ID：BP-PR06-CATALOG-LOADER-DECISIONS-001
文書バージョン：1.0.0
ステータス：draft
対象：BESTpay v2 PR-06

## 1. 目的

PR-06では、PR-05で確定したJSON Schema契約を使用して、
カタログファイルを安全に読み込み、検証し、公開可能な
CatalogSnapshotを生成する境界を実装する。

本PRはカタログの読み込みと整合性検証を対象とし、
条件式の評価、還元計算、画面接続、SQLite移行は対象外とする。

## 2. レイヤー配置

### domain

次を配置する。

- CatalogDiagnosticSeverity
- CatalogDiagnosticCode
- CatalogDiagnostic
- CatalogSnapshot
- CatalogIntegrityValidatorのドメイン規則

domainはFlutter、ファイルシステム、暗号化パッケージ、
JSON Schemaライブラリへ依存しない。

### application

次のPortおよびロード処理を配置する。

- CatalogFileSource
- CatalogSchemaValidator
- ContentHasher
- CatalogLoader
- CatalogLoadResult

applicationはdomainおよびcoreへ依存できるが、
infrastructure、presentation、既存v1実装へ依存しない。

### infrastructure

次のAdapterを配置する。

- SHA-256 ContentHasher
- Draft 2020-12 JSON Schema Validator
- MemoryCatalogFileSource
- 将来のasset/file source接続点

JSON Schemaライブラリ固有型をdomainまたはapplicationへ公開しない。

## 3. 読み込み順序

Catalog Loaderは次の順序で処理する。

1. catalog_manifest.jsonをbyte列として読み込む。
2. UTF-8 JSONとして解析する。
3. manifestのschemaVersion、catalogVersion、generatedAtを検証する。
4. manifestに12ファイルが過不足なく存在することを検証する。
5. fileNameの重複とfileName/schemaId対応を検証する。
6. 各requiredファイルの存在を検証する。
7. 各ファイルの元byte列からSHA-256を計算する。
8. contentHashと計算結果を比較する。
9. 各ファイルをUTF-8 JSONとして解析する。
10. Draft 2020-12 Schemaで検証する。
11. 全ファイルのcatalogVersion一致を検証する。
12. StableIdを収集し、重複を検証する。
13. 定義済み参照の存在を検証する。
14. 循環参照および意味的制約を検証する。
15. diagnosticsを集約する。
16. fatalおよびerrorが0件の場合だけCatalogSnapshotを公開する。

後続処理は、前段で安全に継続できないfatalが発生した場合に
無理に実行しない。ただし、独立して検査可能な診断は可能な限り集約する。

## 4. 公開可否

診断severityは次の4種類とする。

- fatal
- error
- warning
- info

公開規則は次とする。

- fatalが1件以上：公開不可
- errorが1件以上：公開不可
- warningのみ：公開可能
- infoのみ：公開可能
- 診断なし：公開可能

CatalogSnapshotは公開可能な状態だけを表す。
失敗時のdiagnosticsはCatalogLoadResultで返す。

## 5. 診断コード

診断コードは統合作業チェックポイントSection 24を正本とする。

- CAT-F001～CAT-F007
- CAT-E001～CAT-E013
- CAT-W001～CAT-W010
- CAT-I001～CAT-I004

診断コードは永続的な文字列として扱い、enum indexを保存しない。
severityはコード先頭の区分から一意に決定する。

未実装または予約中のコードも、別の意味へ再利用しない。

## 6. SHA-256

contentHashは対象ファイルの元byte列から計算する。

次の処理は禁止する。

- JSON解析後の再エンコード結果から計算する
- 空白や改行を正規化してから計算する
- キー順を変更してから計算する
- UTF-8以外へ変換してから計算する

SHA-256実装にはcrypto 3.0.7を使用する。

## 7. JSON Schema

JSON Schema Draft 2020-12を明示して検証する。

実装にはjson_schema 5.2.2を使用する。

URN参照解決では、参照文字列に`#`が存在する場合だけ
fragment部分を除去する。fragmentを持たないURNへ
不要な末尾`#`を追加してはならない。

全30 SchemaをIDでregistryへ登録し、ローカルURN参照だけで
同期的に解決可能な構成とする。

## 8. CatalogSnapshot

CatalogSnapshotは少なくとも次を保持する。

- schemaVersion
- CatalogVersion
- generatedAt
- 読み込んだ12カタログ文書
- StableId参照用index
- warningおよびinfo diagnostics

保持するMapおよびListは防御的コピーを行い、外部から変更できない
read-only構造として公開する。

PR-06では各JSON項目をPR-07/PR-08用の計算Domain Modelへ変換しない。

## 9. 参照整合性

存在確認可能なカタログ間参照だけを検証する。

関連カタログがPR-06の12ファイルに存在しない次の参照は、
未知参照としてエラーにしない。

- brandIds
- locationIds
- tags
- transactionTags
- exclusiveGroupId
- aggregationKey
- scopeKey

ただし、形式がStableId契約に違反する場合は別途診断対象とする。

## 10. 循環参照

禁止されている循環を検出する。

- RewardRule mirror
- ID migration
- MerchantCategory parent

FundingRelationの循環は、禁止する正本規則が存在しないため
PR-06ではエラーにしない。

## 11. 予約機能

次はコードを予約するが、PR-06では発生させない。

- CAT-F007 signatureInvalid
- CAT-E009 exactRoundingProducedFraction

署名フィールドは現在のSchemaに存在しない。
exact丸めの計算はPR-08の責務とする。

## 12. 非対象

PR-06では次を行わない。

- ConditionExpressionの評価
- RewardRuleの還元計算
- 商品別実データの作成
- UI接続
- SQLite Schema変更
- DatabaseHelperへの接続
- 既存Calculatorへの接続
- v1 RewardRuleの変更
- 本番assetの配布構成確定
- 電子署名検証
- PR-07以降のDomain Model実装

## 13. テスト方針

最低限、次を自動テストする。

- 診断severityと公開可否
- 診断コード範囲
- 防御的コピー
- manifestの12ファイル完全性
- fileName重複
- fileName/schemaId不一致
- requiredファイル欠落
- SHA-256一致および不一致
- JSON decode失敗
- Draft 2020-12 Schema違反
- URN `$ref`解決
- ConditionExpression再帰Schema
- CatalogVersion不一致
- StableId重複
- 既知参照の欠落
- 禁止循環
- warning/infoのみの場合の公開成功
- fatal/errorを含む場合の公開拒否

テストデータにはMemoryCatalogFileSourceを使用する。
テストはネットワークおよび端末ファイルシステムへ依存させない。

## 14. 完了条件

次のすべてを満たした場合にPR-06実装完了とする。

- dart format合格
- flutter analyze合格
- Architecture Check合格
- PR-05 Schema validation合格
- PR-06単体テスト合格
- 全既存テスト合格
- 作業ツリーに生成物またはキャッシュが残っていない
- fatal/errorを含むカタログが公開されない
- warning/infoだけのカタログが公開可能
- 既存v1計算経路に変更がない
## 15. Technical failures and contract diagnostics

Catalog loading failures are divided into two categories.

### Technical failures

Technical failures are represented by AppError.

Examples include:

- file source read failure
- malformed UTF-8
- malformed JSON
- unregistered JSON Schema
- JSON Schema engine or compilation failure
- general JSON Schema validation failure

The existing catalog-related AppErrorCode values are used for these failures.

### Contract diagnostics

CatalogDiagnostic is used only when the diagnostic has the exact meaning
defined by Section 24 of the integration checkpoint.

A CAT code must not be reused for a different technical failure merely because
its severity is convenient.

CatalogLoadFailure may therefore contain:

- an AppError representing a technical failure;
- one or more fatal/error CatalogDiagnostic values;
- or both when safely collected diagnostics exist before a technical failure.

CatalogSnapshot remains publishable only when no technical failure exists and
no fatal/error CatalogDiagnostic exists.

<!-- PR06-DEFERRED-DIAGNOSTIC-POLICY -->

## Deferred diagnostic policy

PR-06 emits a diagnostic only when its trigger can be determined from a
normative contract without inventing thresholds, comparison baselines, clock
semantics, or evaluation behavior.

The loader and integrity validator implement manifest, required-file,
byte-hash, JSON Schema, catalog-version, StableId, reference, cycle,
`CAT-E002` validity-period, primary-source, mirror-source, and `CAT-E013`
ConditionExpression limit checks.

Malformed JSON, invalid UTF-8, unregistered schemas, and generic JSON Schema
violations remain technical failures represented by `AppError`. They are not
remapped to unrelated `CAT-*` codes.

The following diagnostics are defined by name but do not yet have sufficient
normative trigger rules for PR-06:

- `CAT-E005 divisionByZero`
- `CAT-E009 exactRoundingProducedFraction`
- `CAT-E010 globalRuleWithoutExplicitScope`
- `CAT-E011 invalidCap`
- `CAT-E012 unsupportedDateBasis`
- `CAT-W001` through `CAT-W010`
- `CAT-I001` through `CAT-I004`

Those diagnostics remain available in the diagnostic-code contract but are not
emitted by PR-06 solely from their names. Evaluation, migration, freshness, and
time-relative diagnostics require a later policy-bearing component with an
explicit clock or comparison baseline.

`CAT-F007` and `CAT-E009` remain reserved according to the integration
checkpoint. PR-06 does not assign them a new meaning.

Warnings and informational diagnostics never block snapshot publication.
Fatal and error diagnostics, together with any technical `AppError`, prevent
publication.

# PR-07 Typed Catalog Models Decisions

文書ID：BP-PR07-TYPED-CATALOG-MODELS-DECISIONS-001
文書バージョン：1.0.1
ステータス：draft
対象：BESTpay v2 PR-07

## 1. 目的

PR-06が公開する検証済みCatalogSnapshotを、型安全かつ不変な
カタログDomain Modelへ変換する境界を実装する。

条件評価、還元計算、商品実データ、UI接続、SQLite移行は対象外とする。

## 2. 処理境界

CatalogLoader -> CatalogSnapshot -> TypedCatalogDecoder -> TypedCatalog

CatalogSnapshotはPR-06の公開契約として維持し、破壊的変更を行わない。

TypedCatalogDecoderはapplication層のPortとする。
JSON互換MapからDomain Modelへの変換はinfrastructure層で行う。
Domain ModelにfromJson、toJson、JSONキー名を持ち込まない。

## 3. 型付きカタログ項目

次の12項目を型付きモデルとして定義する。

- PaymentInstrument
- PaymentRoute
- PaymentMode
- FundingRelation
- Merchant
- MerchantGroup
- MerchantCategory
- PointProgram
- ConditionDefinition
- RewardRule
- CatalogSource
- IdMigration

## 4. 既存Value Object

次を再利用し、新しい重複型を作らない。

- StableId
- CalculationDate
- CatalogVersion
- ValidityPeriod
- MoneyYen
- PointAmount
- Rational
- Rate
- RoundingMode
- TriState

## 5. 型構成

Schemaのenumは安定文字列へ明示的に対応するenumとして表現する。
enum indexは保存しない。

Schemaで値が閉じていない文字列フィールドには独自enumを導入しない。

次のoneOfはsealed hierarchyとして表現する。

- ConditionExpression
- RewardCalculation
- PointValueDefinition
- PointExpiration

PR-07ではこれらを型として保持するだけで、評価または計算しない。

## 6. 不変性

すべてのListとMapを防御的にコピーし、変更不能として保持する。
入力順序を維持し、StableId索引も変更不能とする。

TypedCatalogは12種類のカタログ項目を、入力順序を維持する
変更不能なStableId索引として保持する。

schemaVersion、catalogVersion、generatedAt、派生indexes、および
PR-06のwarning/info diagnosticsはCatalogSnapshotが保持する。
TypedCatalogではこれらを重複保持しない。

## 7. 変換Port

TypedCatalogDecoderはAppResult<TypedCatalog>を返す。

失敗時はAppErrorCode.catalogDecodeFailedを使用し、
operationはtypedCatalog.decodeとする。

contextには安全なcatalogVersionのみを格納する。
原因となった例外の型はcauseTypeとして保持する。
raw JSON、例外メッセージ、入力値は公開しない。

最初の失敗でAppFailureを返し、部分的なTypedCatalogを公開しない。
変換失敗をCATコードへ付け替えない。

## 8. 防御的検証

CatalogSnapshotは直接構築できるため、decoderは次を再確認する。

- 12文書の存在
- 文書ルート、items、各項目の実行時型
- 必須フィールド
- 未知enum
- StableId、CalculationDate、Rationalの生成結果
- 数値境界
- union discriminator
- ConditionExpressionの最大深さ10
- ConditionExpressionの最大ノード数100

文字列の暗黙trim、正規化、数値変換を行わない。

ConditionExpressionは再帰的に変換するが、子へ進む前に深さを検査し、
最大深さ10および最大ノード数100を超える入力を拒否する。

## 9. 非対象

- ConditionExpressionの評価
- RewardRuleの還元計算
- stacking、cap、mirrorの実行
- 商品カタログ実データ
- migrationの実行
- UI、Provider、SQLite接続
- 既存v1モデルとの接続
- Schema変更
- CatalogLoader変更

## 10. 依存関係

新しい外部パッケージおよびコード生成パッケージを追加しない。
pubspec.yamlとpubspec.lockを変更しない。

## 11. 完了条件

- dart format成功
- PR-07対象のdart analyze成功
- PR-07 focused test成功
- flutter test全体成功
- Architecture Check成功
- git diff --check成功
- 予定外パス0
- staged path 0
- 生成ファイル変更なし
- PR-06 LoaderとCatalogSnapshotへの破壊的変更なし

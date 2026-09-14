# BESTpay v1からMaxpay v2への移行方針

## 目的

現行BESTpay v1の動作と利用者データを維持しながら、Maxpay v2へ段階的に移行する。

移行は一度に置き換える方式ではなく、テスト、基盤、値オブジェクト、計算、データ、画面の順に小さなPull Requestへ分割する。

## 最優先事項

移行では次を最優先とする。

1\. 利用者データを失わない

2\. 現行計算を意図せず変更しない

3\. 旧バックアップを読み込める状態を維持する

4\. 問題発生時に旧経路へ戻せるようにする

5\. 各段階でテストとビルドを実行する

## 現行コードの扱い

次のディレクトリは、当面Legacyコードとして維持する。

- lib/db/

- lib/models/

- lib/providers/

- lib/screens/

- lib/utils/

- lib/widgets/

PR-02では次を行わない。

- Legacyファイルの移動

- Legacyクラス名の変更

- Legacy IDの変更

- SQLite列の変更

- Calculatorの変更

- DatabaseHelperの変更

- AppStateの変更

- StoreDetailScreenの変更

- SettingsScreenの変更

- main.dartの起動経路変更

## 移行の基本方向

Legacyからv2へのデータ変換は、Adapterを経由する。

変換方向:

- Legacyデータ

- Legacy Adapter

- v2 Domainモデル

v2 Domainモデルから旧モデルへ依存する設計を主要経路にしない。

v2計算エンジンから旧Calculatorを呼び出さない。

v2画面から旧DatabaseHelperを直接呼び出さない。

## 段階的な移行

### PR-00

現行環境、構成、ビルド結果、既知の問題を記録する。

### PR-01およびPR-01B

現行Calculator、モデル、SQLite、バックアップ、表示形式、接続状態をCharacterization Testとして固定する。

これらのテストは現行挙動の記録であり、すべてをv2の正しい仕様として承認するものではない。

### PR-02

v2の依存方向と共通基盤を追加する。

対象:

- AppResult

- AppError

- AppErrorCode

- Clock

- SystemClock

- Architecture Check

- アーキテクチャ文書

PR-02では新しい基盤を現行アプリの起動経路へ接続しない。

### PR-03以降

後続PRで、共通値オブジェクトと業務モデルを段階的に追加する。

候補:

- MoneyYen

- Rational

- MicrosYen

- PointAmount

- Rate

- TriState

- ValidityPeriod

- StableId

- CatalogVersion

- CalculationDate

各機能は単体テストを追加してから本番経路へ接続する。

## データ移行方針

データ移行は、読み取り、検証、変換、プレビュー、スナップショット、適用の段階に分ける。

推奨順序:

1\. Legacyデータを読み取る

2\. 元データを変更せずに形式を検証する

3\. v2モデルへ変換する

4\. 警告と変換結果をプレビューする

5\. 既存データのスナップショットを作成する

6\. トランザクション内で適用する

7\. 適用後の整合性を検証する

8\. 失敗時はロールバックする

9\. 成功を確認するまで旧データを削除しない

## バックアップ移行方針

現行v1バックアップには、バージョン検証や完全な復元が不足している。

v2では少なくとも次を識別する。

- formatId

- schemaVersion

- appVersion

- catalogVersion

- exportedAt

復元時は次を必要とする。

- 形式検出

- バージョン検証

- 内容検証

- 復元内容のプレビュー

- 適用前スナップショット

- atomicな適用

- 失敗時ロールバック

- 復元結果の明示

PR-02ではバックアップ形式を変更しない。設計と共通基盤だけを追加する。

## 既知のLegacy挙動

Characterization Testで記録した既知の挙動には、次が含まれる。

- StoreDetailScreenがcustomRatesをCalculatorへ渡さない

- バックアップのversionが検証されない

- reward\_rulesがバックアップから復元されない

- usage\_historyがバックアップ対象外

- payment\_methodsは一部フィールドだけ復元される

- storesはお気に入り状態だけ復元される

- 不正な行を含むバッチが失敗する

- 同率ランキングに明示的な優先順位がない

- 計算にdoubleが使用されている

既知の不具合を修正する場合は、次の順序を守る。

1\. 現行Characterization Testを確認する

2\. 望ましい挙動のテストを追加する

3\. 本番コードを修正する

4\. Legacy専用テストを維持または理由付きで更新する

5\. 利用者への影響を記録する

## 機能フラグ

PR-02では、利用者設定としてv2機能フラグを追加しない。

未実装の機能を利用者へ公開せず、誤って本番経路を切り替えないためである。

必要になった場合は、コンパイル時定数または内部設定として別PRで導入する。

## ロールバック

PR-02は原則として新規ファイルだけを追加する。

問題が発生した場合は、PR-02で追加した次の領域を削除することでロールバックできる。

- lib/core/

- test/core/

- test/architecture/

- tool/check\_architecture.dart

- docs/architecture/

現行コードからPR-02の新規基盤を呼び出さないため、ロールバック時にv1データや既存画面を変更する必要はない。

## 各PRの確認項目

各移行PRで次を確認する。

- dart format

- flutter analyze

- flutter test

- Characterization Test

- Architecture Check

- debug APK build

- git diff check

- 変更ファイル一覧

- 秘密情報が含まれていないこと

DBまたはバックアップを変更するPRでは、追加で次を確認する。

- 実データをテストに使用していない

- 一時データベースを使用している

- スナップショットが作成される

- 途中失敗時にロールバックされる

- 旧形式を読み込める

- 不明な形式を安全に拒否する

## PR-02の終了条件

PR-02完了時点で次を満たす。

- v2の依存方向が文書と自動検査で定義されている

- AppResultがPure Dartで利用できる

- AppErrorが安全な構造化エラーを表現できる

- Clockでテスト時刻を固定できる

- coreがFlutterやSQLiteへ依存していない

- 現行main.dartを変更していない

- 現行Calculatorを変更していない

- SQLiteスキーマとseedデータを変更していない

- v1バックアップ形式を変更していない

- 全Characterization Testが成功する

- debug APKをビルドできる

- 新しいruntime dependencyを追加していない

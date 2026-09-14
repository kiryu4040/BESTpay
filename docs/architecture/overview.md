# Maxpay v2 アーキテクチャ概要

## 文書情報

- 対象リポジトリ: https://github.com/kiryu4040/BESTpay

- PR: PR-02

- 基準コミット: dd26225b7f7d4b2288eeb8cc65c6c5114df3f778

- 目的: 現行BESTpay v1を維持したまま、Maxpay v2を段階的に実装するための境界を定義する

- UI変更: なし

- SQLite変更: なし

- 計算結果変更: なし

- バックアップ形式変更: なし

## 設計上の優先順位

1\. 計算精度

2\. ユーザーデータ保護

3\. 説明可能性

4\. 互換性

5\. テスト容易性

6\. UI完全性

7\. 性能

## レイヤー構成

Maxpay v2は、core、domain、application、infrastructure、presentation、composition、legacyの領域に分割する。

### core

アプリ全体で共有する、技術や業務機能に依存しない最小限の型を配置する。

対象例:

- AppResult

- AppError

- AppErrorCode

- Clock

- SystemClock

- 後続PRで追加する共通値オブジェクト

coreはFlutter、SQLite、画面、Legacyモデルへ依存しない。

### domain

業務ルールと不変条件を配置する。

対象例:

- 還元計算

- 条件評価

- 決済手段

- 店舗

- ポイント

- カタログ

- ユーザープロファイル

- Repository契約

domainはcoreとDart SDKだけに依存する。

### application

ユースケースと処理の調整を担当する。

対象例:

- 計算要求

- カタログ読み込み

- マイグレーション

- バックアップ

- 起動処理

- Repositoryを組み合わせる処理

applicationはcoreとdomainへ依存できるが、Flutter Widget、BuildContext、SQLite実装には依存しない。

### infrastructure

外部技術との接続を担当する。

対象例:

- SQLite

- SharedPreferences

- Asset JSON

- ファイルシステム

- Flutter plugin

- Repository実装

- Legacy DB読み込み

- Legacyバックアップ読み込み

infrastructureに独自の還元計算やUI状態を置かない。

### presentation

Flutterの画面とUI状態を担当する。

対象例:

- View

- ViewModel

- Controller

- UI State

- 利用者操作

- 画面遷移要求

presentationからSQLite、旧DatabaseHelper、旧Calculatorを直接呼び出す新規コードは追加しない。

### composition

アプリケーション全体の依存を組み立てる。

対象例:

- Clock生成

- Repository実装生成

- Application Service生成

- Controller生成

- 内部Feature Flag適用

compositionに計算、DBクエリ、JSON解析、画面表示を実装しない。

### legacy

現行BESTpay v1とMaxpay v2を接続するAdapterを配置する。

PR-02ではAdapterを実装せず、境界だけを定義する。

## 現行Legacyコード

次の既存ディレクトリは当面Legacyとして扱う。

- lib/db/

- lib/models/

- lib/providers/

- lib/screens/

- lib/utils/

- lib/widgets/

PR-02では、これらをlib/legacy/へ移動しない。

理由:

- importの大量変更を避ける

- 現行動作への影響を避ける

- Characterization Testの基準を維持する

- v2基盤の追加とLegacy移動を別の変更として扱う

## PR-02で追加する構造

PR-02では、必要な実装ファイルが存在する次の領域だけを追加する。

- lib/core/errors/

- lib/core/result/

- lib/core/time/

- test/architecture/

- test/core/

- tool/

- docs/architecture/

未使用のdomain、application、infrastructure、presentationディレクトリを、空の.gitkeepだけで追加しない。

## PR-02で変更しないもの

- lib/main.dartの起動経路

- Calculator

- DatabaseHelper

- SQLiteスキーマ

- seedデータ

- StoreDetailScreen

- AppState

- バックアップ形式

- Application ID

- アプリのバージョン番号

- 利用者向け画面

- 現行計算結果

## 本番接続方針

PR-02で追加するv2基盤は、現行main.dartから呼び出さない。

v2 Composition Rootおよび各機能の本番接続は、単体テストと移行経路が成立した後の独立したPRで行う。

## PR-02の完了条件

- 依存方向が文書化されている

- 禁止importを自動検査できる

- AppResultをPure Dartで利用できる

- AppErrorが安全な構造化エラーを表現できる

- Clockで現在時刻をテストから固定できる

- coreがFlutterやSQLiteへ依存していない

- 全Characterization Testが引き続き成功する

- 現行アプリの起動、計算、保存動作を変更していない

- 新しいruntime dependencyを追加していない

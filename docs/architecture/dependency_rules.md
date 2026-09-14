# Maxpay v2 依存方向規則

## 基本原則

依存は外側のレイヤーから内側のレイヤーへ向ける。

基本的な依存方向:

- presentationからapplication

- presentationからdomain

- presentationからcore

- applicationからdomain

- applicationからcore

- infrastructureからapplicationで定義されたPort

- infrastructureからdomain

- infrastructureからcore

- domainからcore

- coreからDart SDK

- compositionから各レイヤー

## coreの規則

coreは、技術や業務機能に依存しない共通型を配置する領域である。

coreから次への依存を禁止する。

- Flutter

- domain

- application

- infrastructure

- presentation

- composition

- legacy

- sqflite

- shared\_preferences

- file\_picker

- path\_provider

coreで利用できるのは、原則としてDart SDKだけとする。

## domainの規則

domainは、業務ルールと不変条件を配置する領域である。

domainから次への依存を禁止する。

- Flutter

- application

- infrastructure

- presentation

- composition

- legacy

- sqflite

- shared\_preferences

- file\_picker

- Android API

- 旧BESTpayモデル

domainはcoreとDart SDKへ依存できる。

## applicationの規則

applicationは、ユースケースと処理の調整を担当する。

applicationから次への依存を禁止する。

- Flutter Widget

- BuildContext

- Navigator

- infrastructure実装

- presentation

- legacy

- sqflite

- shared\_preferences

- file\_picker

applicationはcore、domain、およびapplication内で定義されたPortを利用できる。

## infrastructureの規則

infrastructureは、SQLite、ファイル、プラグインなどの技術的な実装を担当する。

infrastructureから次への依存を禁止する。

- presentation

- Flutter Widget

- BuildContext

- Navigator

- UI状態

- 画面文言

infrastructureへ独自の還元計算や条件評価を実装しない。

## presentationの規則

presentationは、Flutter画面、UI状態、利用者操作を担当する。

presentationの新規コードから次への直接依存を禁止する。

- infrastructure

- sqflite

- shared\_preferences

- file\_picker

- 旧DatabaseHelper

- 旧Calculator

presentationはapplication、domain、coreへ依存できる。

## compositionの規則

compositionは各レイヤーの実装を組み立てるため、各レイヤーへ依存できる。

ただし、compositionには次を実装しない。

- 還元計算

- 条件評価

- DBクエリ

- JSON解析

- マイグレーション処理

- UI表示

- エラー文言変換

## RepositoryとPortの配置

業務概念の保存・取得契約はdomainへ配置する。

例:

- CatalogRepository

- UserProfileRepository

- PaymentMethodRepository

- StoreRepository

特定ユースケースの外部機能契約はapplicationへ配置する。

例:

- BackupFileReader

- BackupFileWriter

- MigrationTransaction

- AppVersionProvider

- DeviceInfoProvider

技術を利用する実装はinfrastructureへ配置する。

例:

- AssetCatalogRepository

- SqliteUserProfileRepository

- SharedPreferencesSettingsRepository

- LocalBackupFileReader

- LegacyV1DatabaseReader

Repository契約の名前には、SQLiteなどの実装技術名を含めない。

## Legacy境界

許可する変換方向:

- Legacyモデル

- Legacy Adapter

- v2 Domainモデル

Legacyモデルからv2 Domainモデルへの変換は、Legacy Adapterを経由する。

次の依存を禁止する。

- v2 Domainモデルが旧モデルを主要モデルとして利用する

- v2計算エンジンが旧Calculatorを呼び出す

- v2 Presentationが旧DatabaseHelperを直接呼び出す

PR-02ではLegacy Adapterを実装せず、境界だけを定義する。

## Architecture Checkの対象

PR-02では、存在する次の新規ディレクトリを検査する。

- lib/core/

- lib/domain/

- lib/application/

- lib/infrastructure/

- lib/presentation/

- lib/composition/

- lib/legacy/

存在しないディレクトリはエラーにしない。

## 一時的な検査対象外

次の現行コードは、PR-02ではArchitecture Checkの対象外とする。

- lib/db/

- lib/models/

- lib/providers/

- lib/screens/

- lib/utils/

- lib/widgets/

- lib/main.dart

この除外は恒久的なものではない。v2へ移行したファイルから順に検査対象へ含める。

## 違反時の出力

Architecture Checkは、違反時に次を表示する。

- ファイルパス

- 行番号

- import文

- 違反ルールID

規則IDの例:

- ARCH-CORE-001: core must not import Flutter

- ARCH-CORE-002: core must not import outer layers

- ARCH-DOMAIN-001: domain must not import infrastructure

- ARCH-APP-001: application must not import presentation

- ARCH-PRES-001: presentation must not import sqflite

- ARCH-PRES-002: presentation must not import legacy Calculator

違反が1件以上ある場合、検査コマンドは非0の終了コードを返す。

# BESTpay PR-00 現行ベースライン

## 1. 文書情報

- 記録日: 2026-09-14

- リポジトリ: https://github.com/kiryu4040/BESTpay

- 基準ブランチ: main

- 基準コミット: de16d76f9f448f9ae297c124373e5ed2d51c834f

- 基準コミット表示: de16d76 Delete .github/workflows/main.yml

- 作業ブランチ: docs/pr-00-baseline

この文書は、Maxpay v2実装前のBESTpay v1の状態を記録する。

PR-00ではアプリケーションの動作を変更しない。

## 2. 検証環境

- OS: Windows 11

- Flutter: 3.24.5

- Flutter revision: dec2ee5c1f

- Dart: 3.5.4

- DevTools: 2.37.3

- Java: Eclipse Temurin OpenJDK 17.0.20.1

- Android SDK: 36.1.0

リポジトリのBUILD\_INSTRUCTIONS.mdとworkflows/build-apk.ymlが指定するFlutter 3.24.5およびJava 17を使用した。

Flutter 3.44.6ではCardTheme APIとGradle最低バージョンの互換性問題が発生した。そのため、既存コードやGradleを変更せず、指定環境へ切り替えた。

## 3. Android設定

android/app/build.gradleで確認した値:

- namespace: com.bestpay.bestpay

- applicationId: com.bestpay.app

- minSdk: 26

- targetSdk: 34

- versionCode: 1

- versionName: 1.0.0

- Java compatibility: 1.8

- Kotlin JVM target: 1.8

- release signingConfig: debug

pubspec.yamlで確認した値:

- version: 1.1.0+2

- Dart SDK constraint: ^3.5.0

Flutter側とAndroid側でバージョン表記が一致していない。PR-00では修正せず、既知の不整合として記録する。

## 4. 依存関係

基準コミットにはpubspec.lockが含まれていない。

Flutter 3.24.5でflutter pub getを実行した結果、60依存関係が解決された。生成されたpubspec.lockは、リポジトリ外の次の場所へ保存した。

artifacts/pr-00-de16d76/pubspec.lock.generated

pubspec.lockがないため、実行日やFlutter SDKによって依存パッケージの解決結果が変化する可能性がある。

## 5. 静的解析

Flutter 3.24.5でflutter analyzeを実行した。

結果:

- error: 0

- warning: 0

- info: 4

確認されたinfo:

1\. home\_screen.dart: constを使用できる宣言

2\. settings\_screen.dart: 非同期処理後のBuildContext使用

3\. store\_detail\_screen.dart: constを使用できるコンストラクター

4\. store\_detail\_screen.dart: constを使用できるコンストラクター

PR-00では修正しない。

## 6. 自動テスト

flutter testの結果:

Test directory "test" not found.

基準コミットには自動テストが存在しない。これはテスト成功ではなく、テスト未実装として扱う。

Characterization TestはPR-01で追加する。

## 7. デバッグAPK

Flutter 3.24.5、Dart 3.5.4、Java 17でflutter build apk --debugを実行した。

結果: 成功

- ファイル名: app-debug.apk

- サイズ: 194358347 bytes

- SHA-256: 46D66E01040668F613AA78BDBC8837D38B5604B26D986D2160D73E7B8410D0EE

検証用APKはリポジトリ外へ保存した。

artifacts/pr-00-de16d76/BESTpay-de16d76-debug.apk

APK自体はGitへコミットしない。

## 8. ビルド時警告

flutter\_plugin\_android\_lifecycleはAndroid SDK 35以上でのコンパイルを要求したが、プロジェクトはAndroid SDK 34を対象としている。

今回のdebug APKビルドは成功したが、将来の依存関係解決結果によってはビルド不能になる可能性がある。

PR-00ではcompileSdk、Gradle、AGP、Kotlinを変更しない。

## 9. 現行構成

### データベース

- DBファイル名: bestpay.db

- DB version: 1

- payment\_methods

- stores

- reward\_rules

- user\_conditions

- custom\_rules

- usage\_history

現行DBには外部キー制約、十分なUNIQUE制約、onUpgradeによるマイグレーションがない。

### モデル

- payment\_method.dart

- reward\_rule.dart

- store.dart

- user\_condition.dart

### 状態管理

- AppState

- Provider

- SharedPreferencesのthemeMode

### 計算

- lib/utils/calculator.dart

- 還元率はdouble

- 基本率、店舗ボーナス、条件ボーナスを加算

- v2の期間集計、三値条件、mirror、構造化traceは未実装

### 画面

- category\_screen.dart

- condition\_screen.dart

- custom\_rule\_screen.dart

- home\_screen.dart

- payment\_list\_screen.dart

- settings\_screen.dart

- simulation\_screen.dart

- store\_detail\_screen.dart

- store\_search\_screen.dart

## 10. バックアップ

現行バックアップには、v2が要求する次の機能がない。

- formatId

- schemaVersionによる厳密な形式管理

- インポート前検証

- 復元プレビュー

- 復元前スナップショット

- Atomic Restore

- 失敗時の完全ロールバック

- v1とv2の形式判定

現行importAllは一部ユーザーデータを削除してから復元する。空データ、不正データ、途中失敗時のデータ消失リスクがある。

実ユーザーのバックアップを使用した破壊的試験は禁止する。

## 11. GitHub Actions

ビルドワークフローはworkflows/build-apk.ymlに存在する。

GitHub Actionsが通常認識する.github/workflows配下には存在しない。そのため、現在は自動実行されない可能性が高い。

PR-00ではワークフローを移動しない。

## 12. 既知の問題と未確認事項

1\. 基準コミットと配布済みアプリの一致は未確認

2\. 配布版の署名証明書は未確認

3\. debug APKの端末への新規インストールは未実施

4\. アプリ起動は未確認

5\. 初期データ件数の実機確認は未実施

6\. 既存ユーザーのDBとバックアップ実物は未確認

7\. pubspec.lockがなく、依存関係の再現性が不十分

8\. testディレクトリが存在しない

9\. StoreDetailScreenからCalculator.rankへcustomRatesが渡されていない

10\. 過去の仕様書のAndroid設定値の一部が実ファイルと一致しない

11\. release APKのビルドは未実施

12\. バックアップ復元の安全性は未確認

未実施項目を成功扱いしない。

## 13. PR-00で変更しないもの

- lib配下のDartコード

- Androidビルド設定

- pubspec.yaml

- pubspec.lock

- SQLite DB schema

- 初期データ

- 計算結果

- バックアップ形式

- UI

- Application ID

- versionCodeとversionName

- GitHub Actions

## 14. PR-01への引継ぎ

PR-01では現行挙動をCharacterization Testとして固定する。

優先対象:

1\. Calculatorの基本率計算

2\. 条件ボーナス

3\. 還元額

4\. 同率ランキング順

5\. SQLite DB versionとテーブル

6\. 初期データ件数

7\. 店舗検索

8\. ユーザー条件CRUD

9\. カスタムルールCRUD

10\. お気に入り

11\. バックアップ出力

12\. 復元時の部分データと空データの挙動

13\. themeMode

14\. StoreDetailScreenのcustomRates非連携

Characterization Testの値をMaxpay v2の正しい仕様値として流用しない。

## 15. PR-00完了条件

- 基準コミットを記録した

- 指定環境でdebug APKをビルドできた

- APKのSHA-256を記録した

- テスト不在を記録した

- 未確認事項を明記した

- 実行時コードを変更していない

- DB、計算、画面、バックアップを変更していない

- APK、秘密鍵、個人データをコミットしていない

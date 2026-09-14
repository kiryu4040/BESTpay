# Maxpay v2 エラー処理方針

## 目的

エラーを文字列やnullだけで表現せず、安定したコードと安全な情報を持つAppErrorとして表現する。

AppErrorは、次の目的で利用する。

- 失敗の種類を機械的に判定する

- 再試行可能か判断する

- ログやテストで安定した識別子を使用する

- 内部エラーと利用者向け表示を分離する

- 機密情報の漏えいを防止する

## AppErrorの基本構造

AppErrorは最低限、次の情報を持つ。

- code

- operation

- retryable

- context

必要に応じて次を持つことができる。

- safeMessage

- debugMessage

- causeType

- occurredAt

codeとoperationは必須とする。

## AppErrorCode

AppErrorCodeは、安定したエラー分類を表現する。

初期分類:

### 共通

- unknown

- invalidArgument

- invalidState

- unsupportedOperation

- cancelled

- timeout

### データ

- notFound

- duplicate

- conflict

- dataCorrupted

- dataValidationFailed

- incompatibleVersion

### カタログ

- catalogNotFound

- catalogReadFailed

- catalogDecodeFailed

- catalogValidationFailed

- catalogVersionUnsupported

- catalogReferenceBroken

### ストレージ

- databaseOpenFailed

- databaseReadFailed

- databaseWriteFailed

- databaseTransactionFailed

- preferencesReadFailed

- preferencesWriteFailed

### マイグレーション

- migrationSourceUnknown

- migrationValidationFailed

- migrationMappingFailed

- migrationCommitFailed

- migrationAlreadyRunning

- migrationRollbackFailed

### バックアップ

- backupReadFailed

- backupWriteFailed

- backupFormatUnknown

- backupVersionUnsupported

- backupValidationFailed

- backupRestoreFailed

- backupSnapshotFailed

### 計算

- calculationInputInvalid

- calculationRuleInvalid

- calculationConditionUnknown

- calculationOverflow

- calculationNonDeterministic

PR-02では、これらすべてを実際の処理へ接続しない。後続PRで必要なコードを段階的に使用する。

## コードの安定性

AppErrorCodeには次の規則を適用する。

- 一度使用した名前の意味を変更しない

- 別の意味で名前を再利用しない

- 廃止する場合はdeprecatedとして扱う

- UI表示文をコード名に含めない

- enumのindexを保存しない

- 保存が必要な場合は安定した文字列名を使用する

## operation

operationは、失敗した処理を識別する短い文字列とする。

例:

- app.bootstrap

- catalog.load

- catalog.validate

- database.open

- migration.detect

- backup.import

- backup.restore

- calculation.execute

クラス名、ファイル名、行番号をoperationとして使用しない。

## retryable

retryableは、同じ操作を再試行できる可能性を表現する。

- true: 一時的なI/O失敗など、再試行できる可能性がある

- false: 入力不正や非対応バージョンなど、そのまま再試行しても解決しない

retryableは利用者向けボタンを直接決定するものではない。最終的な表示判断はpresentationで行う。

## context

contextには、問題の調査に必要な最小限の安全な情報だけを保持する。

contextは生成時に防御コピーし、呼び出し側から変更できないようにする。

格納可能な例:

- catalogVersion

- schemaVersion

- operationStep

- safeIdentifier

- expectedFormat

格納禁止の例:

- カード番号

- 認証トークン

- APIキー

- 署名鍵

- パスワード

- バックアップ本文

- 実利用履歴の明細

- ユーザープロファイル全体

- SQLite行全体

- ファイル内容全体

- 個人を識別できる情報

## safeMessageとdebugMessage

safeMessageは、個人情報や内部実装を含まない安全な説明に限定する。

debugMessageは開発者向け情報として扱い、通常の利用者画面へ直接表示しない。

どちらにも次を含めない。

- パスワード

- トークン

- APIキー

- バックアップ本文

- SQLの値

- 個人情報

## toStringの安全性

AppErrorのtoStringには、次の情報だけを含める。

- code

- operation

- retryable

toStringへ次を出力しない。

- raw exception

- stack trace全体

- debugMessage全文

- contextの全内容

- ファイル内容

- SQL

- バックアップ本文

- 個人情報

## 例外との境界

外部I/Oやプラグインの境界では、復旧可能な例外をAppErrorへ変換し、AppResultで返す。

変換対象の例:

- FormatException

- FileSystemException

- DatabaseException

- JSONデコード失敗

- PlatformException

原則として捕捉しないもの:

- AssertionError

- プログラマーバグ

- 到達不能状態

- テストで検出すべき不変条件違反

AppResultの内部で例外を無条件に握りつぶさない。

## UIとの境界

DomainとApplicationは、最終的な日本語表示文を決定しない。

PresentationがAppErrorCodeを利用者向け文言へ変換する。

debugMessage、raw exception、stack trace、内部ファイルパスは、通常の利用者画面へ表示しない。

## 同値判定

PR-02ではAppError自体の独自同値演算子を必須としない。

将来同値判定を実装する場合は、次を比較対象として検討する。

- code

- operation

- retryable

- 安全なcontext

cause、stack trace、発生時刻は同値判定に含めない。

## ログとの分離

AppErrorはログ出力処理を実行しない。

ログ出力、クラッシュ収集、利用者向け表示は、それぞれ別の責務として実装する。

PR-02では新しいログライブラリを追加しない。

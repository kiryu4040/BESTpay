# Maxpay v2 Clock方針

## 目的

現在時刻をDateTime.nowから直接取得する処理を減らし、時刻に依存する計算とテストを決定論的にする。

Clockは、現在時刻を必要とする処理へ外部から時刻を渡すための抽象化である。

## Clockが必要な処理

- 計算基準日の決定

- ルール有効期間の判定

- カタログ確認日の記録

- バックアップ作成時刻の記録

- マイグレーション実行時刻の記録

- カスタムルール作成時刻の記録

- 月次集計

- 年次集計

- リリース判定

- 安全なログ時刻の記録

## Clockの契約

Clockは、現在のUTC時刻を返す。

概念的な公開API:

- DateTime nowUtc()

Clockは状態を変更しない。

同じClockインスタンスを呼び出した結果が常に同じである必要はない。SystemClockは実際の現在時刻を返し、FixedClockは固定時刻を返す。

## UTC方針

DomainおよびApplication内部ではUTCを基準とする。

原則:

- ClockはUTCのDateTimeを返す

- SystemClockはDateTime.now().toUtc()を返す

- 計算期間の比較はUTCまたは明示された業務基準日で行う

- 利用者向け表示時にローカル時刻へ変換する

- ローカル時刻とUTCを暗黙に混在させない

- DateTimeのisUtcをテストする

日本時間の日付境界が業務上必要な場合は、UTC時刻から明示的に変換する。端末の暗黙のタイムゾーン設定だけに依存しない。

## SystemClock

SystemClockは、本番環境で実際の現在時刻を提供する。

責務:

- 現在のUTC時刻を返す

- Dart SDKだけを利用する

- 変更可能な状態を持たない

- ログ出力を行わない

- タイマーを管理しない

SystemClockはlib/core/time/system\_clock.dartへ配置する。

## FixedClock

FixedClockはテスト専用のClock実装とする。

責務:

- コンストラクタで受け取った時刻を保持する

- 常に同じUTC時刻を返す

- システム時刻を参照しない

FixedClockは原則としてtest/helpers/fixed\_clock.dartへ配置し、本番コードから参照しない。

## 時刻の正規化

FixedClockへUTCではないDateTimeが渡された場合は、UTCへ変換して保持する。

これにより、Clock.nowUtcが返す値は常にisUtcがtrueになる。

## 呼び出し回数

同一処理の途中でClockを何度も呼び出さない。

処理開始時に基準時刻を一度取得し、その値を処理全体で使用する。

これにより、日付や月が処理途中で変わることによる不整合を防ぐ。

## DateTime.nowの使用制限

新しいDomainおよびApplicationコードからDateTime.nowを直接呼び出さない。

許可される主な場所:

- SystemClock

- UI表示だけに限定された処理

- テスト環境を含め、時刻固定が不要であることが明確な技術処理

時刻が計算結果、保存値、有効期間、バックアップ、マイグレーションへ影響する場合はClockを利用する。

## Clockの単体テスト

PR-02では次を確認する。

- SystemClockがUTCを返す

- FixedClockが固定時刻を返す

- FixedClockへローカル時刻を渡した場合にUTCへ正規化される

- 年末の固定時刻を扱える

- うるう日の固定時刻を扱える

- UTCと日本時間の日付境界を確認できる

年末テストの基準値:

- 2026-12-31T23:59:59Z

うるう日テストの基準値:

- 2028-02-29T00:00:00Z

日本時間境界テストの例:

- UTCの2026-09-13T15:00:00Z

- 日本時間の2026-09-14T00:00:00+09:00

## PR-02で行わないこと

- 現行コード内のDateTime.nowを一括置換しない

- 現行DatabaseHelperへClockを注入しない

- 現行CalculatorへClockを注入しない

- main.dartから新しいClockを使用しない

- タイムゾーン用のruntime dependencyを追加しない

- Clockへログや設定の責務を持たせない

既存コードへのClock導入は、対象機能をv2へ移行する後続PRで行う。

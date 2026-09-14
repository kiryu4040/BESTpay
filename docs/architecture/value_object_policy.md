# Maxpay v2 共通値オブジェクト方針

## 文書情報

- 対象リポジトリ: https://github.com/kiryu4040/BESTpay
- PR: PR-03
- 基準コミット: 977e22fcc16069cedc2fddd790efed2891c8c71b
- 対象: Pure Dartの共通値オブジェクト
- UI変更: なし
- DB変更: なし
- 現行計算結果変更: なし
- runtime dependency追加: なし

## 目的

金額、比率、ポイント、条件状態、識別子、バージョン、計算日をプリミティブ値のまま扱わず、単位と不変条件を型で表現する。

小数計算にdoubleを使用せず、丸め位置と丸め方式を明示することで、還元計算を決定論的にする。

## PR-03の対象

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
- RoundingMode

## 共通原則

- 金額と還元率の計算にdoubleを使用しない
- 不正な値を持つインスタンスを生成できないようにする
- 値は生成後に変更できない
- 同じ値は等価として比較できる
- hashCodeは同値判定と一致させる
- toStringはデバッグ用とし、UI表示形式を兼ねない
- enumのindexを保存しない
- 保存時は安定した文字列名または明示的な数値を使用する
- nullを0、false、unknownの代用にしない
- Flutter、SQLite、SharedPreferencesへ依存しない
- 不正入力はAppErrorとAppResultで表現する
- プログラマーバグをAppResultで無条件に隠さない

## MoneyYen

MoneyYenは整数円を表現する。

- 内部表現はint
- 小数円を保持しない
- 加算、減算、比較を正確に行う
- 負数を許可する
- 購入金額を非負に制限する責務は後続のDomain型へ置く
- UI用の円記号や桁区切りを保持しない
- JSON等へ保存する場合は整数円として保存する

## Rational

Rationalは正確な有理数を表現する。

- numeratorとdenominatorをintで保持する
- denominatorが0の値を禁止する
- denominatorは常に正数へ正規化する
- 最大公約数で約分する
- 0は0/1へ正規化する
- 加算、減算、乗算、除算、比較をdoubleなしで行う
- 0による除算を禁止する
- 永続化する場合はnumeratorとdenominatorを保存する

## MicrosYen

MicrosYenは計算途中の100万分の1円を表現する。

- 1円は1,000,000 micros
- 内部表現はint
- 負数を許可する
- MoneyYenへの変換時はRoundingModeを必須とする
- 暗黙に切り捨てない
- UIへ直接表示しない

## PointAmount

PointAmountは整数ポイント数を表現する。

- 内部表現はint
- 負数を許可する
- 取消、調整、差分を表現できる
- 通常付与ポイントを非負に制限する責務は後続のDomain型へ置く
- 小数ポイントを直接保持しない
- 小数計算結果から変換する場合はRoundingModeを必須とする

## Rate

Rateは還元率等の非負の比率を表現する。

- 内部表現にRationalを使用する
- doubleを使用しない
- 負のRateを禁止する
- 100パーセントを超える値を型だけでは禁止しない
- 1パーセントは1/100として表現する
- 0.5パーセントは1/200として表現する
- 表示用パーセント文字列を内部値として保持しない

## RoundingMode

初期対応する丸め方式:

- towardZero
- floor
- ceiling
- halfAwayFromZero

規則:

- 丸め方式をenum indexで保存しない
- 保存する場合はenum名に対応する安定文字列を使用する
- 還元計算で一般的な端数切り捨てはfloorまたはtowardZeroのどちらかを明示する
- 負数でfloorとtowardZeroの結果が異なることをテストする
- ちょうど半分の値はhalfAwayFromZeroで0から遠い整数へ丸める
- 暗黙のデフォルト丸めを導入しない

## TriState

TriStateは条件判定結果を表現する。

値:

- satisfied
- notSatisfied
- unknown

規則:

- unknownをnotSatisfiedへ自動変換しない
- enum indexを保存しない
- NOT unknownはunknown
- ANDではnotSatisfiedを優先し、次にunknownを扱う
- ORではsatisfiedを優先し、次にunknownを扱う
- UI表示文をenumへ含めない

## CalculationDate

CalculationDateは計算基準となるグレゴリオ暦の日付を表現する。

- 年、月、日だけを保持する
- 時刻とタイムゾーンを保持しない
- 存在しない日付を禁止する
- 比較と日数順序を提供する
- UTCのDateTimeから生成する場合はUTCの年月日を使用する
- ローカル時刻から暗黙に変換しない
- 保存形式はYYYY-MM-DDとする

## ValidityPeriod

ValidityPeriodは値やルールの有効期間を表現する。

- 開始日は範囲に含む
- 終了日は範囲に含めない
- startsOnは省略可能
- endsBeforeは省略可能
- 両方省略した場合は無期限
- startsOnとendsBeforeが同じ空期間を許可する
- startsOnがendsBeforeより後の期間を禁止する
- CalculationDateに対するcontainsを提供する

## StableId

StableIdはカタログ等で利用する安定識別子を表現する。

- 空文字を禁止する
- 前後の空白を禁止する
- 小文字英字で開始する
- 使用可能文字は小文字英字、数字、アンダースコア
- 正規表現は `^[a-z][a-z0-9_]*$`
- 表示名をIDとして使用しない
- enum indexをIDとして使用しない
- 生成後に自動で小文字へ変換しない
- 不正な入力は明示的に失敗させる

## CatalogVersion

CatalogVersionはカタログの安定したバージョン文字列を表現する。

- 空文字を禁止する
- 前後の空白を禁止する
- 使用可能文字は英数字、ピリオド、ハイフン、アンダースコア
- 先頭は英数字とする
- 自動的な意味的バージョン比較は行わない
- 一致確認は文字列の完全一致で行う
- 将来の形式変更に備え、表示名やenum indexと結び付けない

## エラー方針

生成に失敗する可能性がある型は、private constructorと生成メソッドを使用する。

不正入力は原則として次を返す。

- AppResultによる失敗
- AppErrorCode.invalidArgument
- 型ごとに安定したoperation

operation例:

- rational.create
- rate.create
- calculationDate.create
- validityPeriod.create
- stableId.create
- catalogVersion.create

raw入力全体や機密情報をAppErrorへ格納しない。

## シリアライズ方針

- MoneyYenは整数円
- Rationalはnumeratorとdenominator
- MicrosYenは整数micros
- PointAmountは整数ポイント
- RateはRationalと同じ正確な構造
- TriStateは安定した文字列名
- RoundingModeは安定した文字列名
- CalculationDateはYYYY-MM-DD
- StableIdは検証済み文字列
- CatalogVersionは検証済み文字列
- ValidityPeriodは開始日と終了日の組

PR-03では既存SQLite schema、seed data、バックアップ形式を変更しない。

## PR-03で変更しないもの

- lib/main.dart
- 現行Calculator
- DatabaseHelper
- SQLite schema
- seed data
- StoreDetailScreen
- AppState
- 既存バックアップ形式
- Application ID
- app version
- 現行画面
- 現行計算結果

## 完了条件

- すべてPure Dartで実装されている
- doubleを計算APIに使用していない
- 不変条件が単体テストで固定されている
- 正数、0、負数、境界値がテストされている
- 丸め方式ごとの差がテストされている
- TriStateの真理値表がテストされている
- 日付と有効期間の境界がテストされている
- 不正なIDとバージョンを生成できない
- enum indexを永続化していない
- Architecture Checkが成功する
- 既存100テストを含む全テストが成功する
- flutter analyzeに新規問題がない
- runtime dependencyを追加していない
- 現行アプリの動作を変更していない

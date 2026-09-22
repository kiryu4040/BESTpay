# PR-08 RewardRule計算エンジン 設計判断

文書ID：BP-PR08-REWARD-ENGINE-DECISIONS-001
文書バージョン：0.1.0
ステータス：review
対象：BESTpay v2 RewardRule計算エンジン

## 1. 目的

本書は、PR-08で実装するRewardRule計算エンジンの境界、入力、
評価順序、出力、失敗方法を固定する。

PR-08は現行BESTpay v1のCalculator、SQLite、画面、Provider、
バックアップ形式およびアプリ起動経路を変更しない。

## 2. ロードマップ差分

統合チェックポイントではPR-07に次が割り当てられていた。

- 4状態条件評価
- ConditionExpression
- confidence
- reasonCode
- calculation trace

実際のPR-07では、ConditionExpressionおよびRewardCalculationの
型定義、TypedCatalog、JSON decoderを実装したが、条件評価、
confidence、reasonCode、calculation traceは実装していない。

RewardRule計算に必要なため、未実装部分をPR-08へ含める。

## 3. PR-08の対象

PR-08は次を実装する。

- ConditionExpressionの反復的評価
- 4状態の条件結果
- RewardRuleのselectorおよびexclusion判定
- 単一RewardCalculationの評価
- 複数RewardRuleの依存関係処理
- replacement
- suppression
- exclusive group
- cap
- mirror
- 明示的rounding
- confidence
- reasonCode
- calculation trace
- 構造化された失敗
- Pure Dart単体テスト

## 4. PR-08の非対象

次はPR-08で実装しない。

- UsagePeriodStateの永続モデル
- 月間、年間、会員年度、プログラム年度の期間更新
- SQLite
- SharedPreferences
- v1データ変換
- バックアップおよび復元
- atomic restoreおよびrollback
- UI、Provider、ViewModel
- main.dartの接続
- 既存Calculatorの変更
- 商品別の実カタログデータ
- 外部サービスまたはネットワーク参照

## 5. 依存方向

計算エンジンはdomainへ配置し、coreとdomainだけに依存する。

禁止する依存：

- Flutter
- SQLite
- SharedPreferences
- infrastructure
- presentation
- legacy
- 既存Calculator
- DateTime.nowの直接呼び出し
- doubleによる確定計算

## 6. 入力モデル

計算入力は不変オブジェクトとし、最低限次を保持する。

- 取引金額
- instrumentId
- modeId
- routeId
- fundingRelationIds
- merchantId
- merchantGroupIds
- categoryIds
- brandIds
- locationIds
- transactionTags
- transactionDate
- postingDate
- settlementDataReceivedDate
- billingDate
- entryDate
- campaignRegistrationDate
- periodEndDate
- 条件値
- 読み取り専用の期間スナップショット

金額はMoneyYenを使用する。通常購入入力では負数を拒否する。

すべてのListとMapはコンストラクタで防御的にコピーし、
変更不能にする。

## 7. 条件値

条件値はTriStateだけに限定しない。

比較式のため、次のtyped valueを表現する。

- String
- int
- bool
- Rational
- List<String | int | bool>
- null
- TriState

condition参照ノードはTriStateを取得する。

comparisonノードはtyped valueを取得して比較する。

欠落した条件値はunknownとする。unknownをfalseへ変換しない。

notApplicableは評価対象外を表し、unknownと区別して保持する。

## 8. ConditionExpression評価

評価は再帰ではなく、明示的なstackを使用した反復処理とする。

PR-07 decoderで検査済みの場合でも、公開評価境界で次を防御する。

- 最大深度10
- 最大ノード数100
- 不明なノード型
- 型不一致
- comparison演算子と値型の不整合

all、any、notにはTriStateの既存4状態演算を使用する。

比較規則：

- equalsおよびnotEqualsは同じ型同士を比較する
- 数値の大小比較はint同士またはRational同士に限定する
- inおよびnotInは右辺のリストへ左辺が含まれるかを判定する
- boolおよびnullへ大小比較を適用しない
- 異種型比較は暗黙変換せず、calculationInputInvalidを返す
- Stringから数値、日付、boolへの暗黙変換を禁止する

## 9. selectorとexclusion

各selector配列が空の場合、その軸は無制限とする。

空でないselector配列では、入力がその配列に含まれることを要求する。

複数のselector軸はAND条件とする。

exclusionはselectorより優先する。

空でないexclusion軸のいずれかが入力と一致した場合、そのルールを
ineligibleとする。

入力に複数IDを持つ軸では、1件以上の共通IDがあれば一致とする。

## 10. 日付と有効期間

RewardRule.dateBasisが指定する日付を使用する。

有効期間は半開区間とする。

- validFrom <= date
- date < validUntilExclusive

必要な日付が入力に存在しない場合、暗黙に別の日付へ代替しない。
そのルールの結果をunknownとし、missingDateBasisを記録する。

timezoneは既存RewardRuleの制約どおりAsia/Tokyoとする。

## 11. 単一計算

### 11.1 unitPoints

取引または集計対象金額をamountUnitで割り、
pointsPerUnitを乗算したRationalを、指定roundingで整数化する。

### 11.2 rateFraction

対象金額へrateを乗算し、指定roundingで整数ポイントへ変換する。

### 11.3 fixedPoints

適格な評価単位につき固定ポイントを1回付与する。

### 11.4 thresholdBonus

期間スナップショットの評価前金額と評価後金額を比較し、
thresholdAmountを新たに横断した場合だけ付与する。

横断条件は次とする。

- periodSpendBefore < thresholdAmount
- thresholdAmount <= periodSpendBefore + currentEligibleAmount

maxAwardsPerPeriodは期間スナップショットで消費済み回数を確認する。
消費済み回数がmaxAwardsPerPeriod以上の場合は0ポイントとし、
thresholdAwardLimitReachedを記録する。

期間情報が存在してもthresholdを横断しない場合は0ポイントとし、
thresholdNotCrossedを記録する。

期間情報が不足する場合は推測せずunknownとし、
periodStateMissingを記録する。

期間スナップショットは読み取り専用とし、最低限次を保持する。

- periodSpendBefore
- awardsConsumed

PR-08は期間スナップショットを更新または永続化しない。

### 11.5 tiered

minimumAmount以上かつmaximumAmountExclusive未満のtierを選択する。

maximumAmountExclusiveがnullの場合は上限なしとする。

tierは重複せず、minimumAmountの昇順であることを要求する。

複数tier一致、順序不正または範囲重複はcalculationRuleInvalidとする。

tier間の空白は許可する。対象金額がどのtierにも一致しない場合は
0ポイントを返す。

選択したtierの計算は対象金額全体へ適用し、限界税率方式にはしない。

### 11.6 none

0ポイントを返す。suppressionまたはreplacementの関係だけを
表現するルールで使用できる。

## 12. rounding

使用可能なroundingは次とする。

- towardZero
- floor
- ceiling
- halfAwayFromZero
- halfToEven
- exact

enum indexを保存または比較に使用しない。

exactで整数化できない場合、例外を外へ漏らさず、
calculationRuleInvalidを返す。

負の確定付与ポイントは通常のRewardRule結果として認めず、
calculationRuleInvalidを返す。

## 13. stacking処理順

処理順は統合チェックポイントに従う。

1. 明示的exclusion
2. replacement
3. suppression
4. exclusiveGroup
5. 通常計算
6. cap
7. mirror
8. 期間ボーナス影響
9. PointValue換算

PR-08は8の期間状態更新と9の金銭価値換算を実行しない。
必要な入力とtrace境界だけを保持する。

同一段階内の決定順は次とする。

1. stacking.applicationOrderの昇順
2. priorityの降順
3. RewardRule.idの辞書順

入力順序に依存してはならない。

## 14. replacement

適格なreplacementルールがreplacesRuleIdsで指定するルールを
置換する。

置換されたルールは計算せず、replaced reasonを記録する。

存在しない置換先IDはcalculationRuleInvalidとする。

自己置換および置換循環はcalculationRuleInvalidとする。

## 15. suppression

適格なsuppressionルールは、suppressRuleIdsまたはsuppressTagsに
一致するルールを抑止する。

抑止されたルールは0ポイントとし、suppressed reasonを記録する。

存在しないsuppressRuleIdはcalculationRuleInvalidとする。

自己抑止はcalculationRuleInvalidとする。

## 16. exclusive group

同じexclusiveGroupIdを持つ適格ルールから1件だけを採用する。

勝者は次の順で決定する。

1. 仮計算後ポイントの降順
2. priorityの降順
3. applicationOrderの昇順
4. RewardRule.idの辞書順

非採用ルールはexclusiveGroupLost reasonを記録する。

仮計算は副作用を持たず、cap消費や期間状態を更新しない。

## 17. dependency

dependsOnRuleIdsの全ルールが最終的に適格かつ非抑止であることを
要求する。

依存先が存在しない場合はcalculationRuleInvalidとする。

依存循環はcalculationRuleInvalidとする。

依存条件が成立しないルールは0ポイントとし、
dependencyNotSatisfied reasonを記録する。

## 18. cap

既存RewardCapの文字列フィールドはSchema上で閉じたenumではない。
PR-08で新しいenumを推測して追加しない。

エンジンは明示的に対応した文字列だけを解釈する。
未対応値は無視せずcalculationRuleInvalidを返す。

capは負の結果を生成してはならない。

cap適用後の値を最終値としてtraceへ記録する。

対応文字列と意味は、実カタログ導入前に別のactive仕様または
本書の改訂で固定する。文書バージョン0.1.0では、RewardCapがnullの
ルールのみ完全対応とする。

## 19. mirror

sourceRuleIdの結果を参照し、multiplierを正確に乗算する。

inheritEligibilityがtrueの場合、source ruleのeligibilityを継承する。

inheritExclusionsがtrueの場合、source ruleのexclusion結果を継承する。

useFinalSourceAmountがtrueの場合、source ruleのcap等適用後の値を使う。
falseの場合、cap適用前の値を使う。

source ruleが存在しない場合はcalculationRuleInvalidとする。

自己参照およびmirror循環はcalculationRuleInvalidとする。

MirrorRewardCalculationにはroundingフィールドが存在しないため、
乗算結果が整数ポイントにならない場合は暗黙に丸めず
calculationRuleInvalidを返す。

## 20. aggregation境界

文書バージョン0.1.0のPR-08が完全対応するaggregation設定は次に
限定する。

- scope = transaction
- aggregationKey = null
- periodMinimumEligibleSpend = 0
- conditionEvaluationTiming = transaction
- incrementalAward = false

これ以外のaggregation設定は、期間単位の入力モデルと期間状態更新が
未実装であるため、推測して計算せずcalculationRuleInvalidを返す。

期間集約およびincrementalAwardは、読み取り専用の期間入力だけでなく
期間開始時点と取引適用後の計算基準を定義する後続PRで実装する。

PR-08のエンジンは期間スナップショットを変更しない。

## 21. confidence

計算結果のconfidenceは次とする。

- confirmed
- estimated
- conditional
- unknown
- ineligible

基本規則：

- 条件と入力が完全で適格ならconfirmed
- 推定入力を使用した場合はestimated
- 条件結果がunknownの場合はconditional
- 必須入力がなく計算不能ならunknown
- 明示的不適格、除外、抑止、置換ならineligible

confidenceはstableな文字列値を持ち、enum indexを保存しない。

## 22. reason code

最低限次をstableなreason codeとして定義する。

- applied
- selectorMismatch
- excluded
- outsideValidityPeriod
- missingDateBasis
- conditionNotSatisfied
- conditionUnknown
- replaced
- suppressed
- exclusiveGroupLost
- dependencyNotSatisfied
- periodStateMissing
- capApplied
- mirrorSourceMissing
- invalidRule
- noRewardCalculation
- thresholdNotCrossed
- thresholdAwardLimitReached

reason codeは表示文言ではない。UI文言へ直接使用しない。

## 23. calculation trace

traceはルール単位の不変レコードのリストとする。

各レコードは最低限次を保持する。

- ruleId
- phase
- eligibility
- confidence
- reasonCodes
- amountBefore
- amountAfter
- pointsBeforeCap
- pointsAfterCap
- sourceRuleId
- details

Listとdetails Mapは防御的にコピーし、変更不能にする。

detailsへ秘密情報、カード番号、口座番号、認証情報を格納しない。

計算結果は少なくとも次を保持する。

- pointsByProgram
- ruleResults
- trace

すべてのMapとListを変更不能にする。

## 24. structured failure

公開計算境界はAppResultを返す。

入力不正：

- AppErrorCode.calculationInputInvalid

ルール不正：

- AppErrorCode.calculationRuleInvalid

未入力条件を確定値として要求した場合：

- AppErrorCode.calculationConditionUnknown

整数オーバーフローまたは実装上の安全限界超過：

- AppErrorCode.calculationOverflow

入力順序等で結果が変化した場合：

- AppErrorCode.calculationNonDeterministic

operationは安定した識別子とする。

contextには安全な値だけを格納する。

例：

- ruleId
- sourceRuleId
- field
- phase
- causeType

生の例外、カード情報、口座情報、Cookie、tokenを格納しない。

## 25. 原子性と決定性

ルール集合に不正なルール、未解決参照または循環がある場合、
部分結果を成功として返さない。

同一入力と同一ルール集合は、ルール入力順序に関係なく
同じ結果と同じtrace順序を返す。

入力コレクションおよびRewardRuleを変更しない。

## 26. 安全限界

サービス拒否および意図しない巨大計算を避けるため、公開境界で
次を検査する。

- ConditionExpression最大深度10
- ConditionExpression最大ノード数100
- RewardRule最大件数10000
- 1ルール当たりselector ID最大件数10000
- 1ルール当たり関係ID最大件数10000
- trace最大件数100000

上限超過は構造化された失敗として返す。

## 27. テスト要件

最低限次をテストする。

- ConditionExpression全ノード
- TriStateの4状態組合せ
- comparison全演算子
- comparisonの異種型拒否
- 条件値欠落
- selectorの空配列
- selector一致および不一致
- exclusion優先
- 有効期間の開始境界と終了境界
- dateBasis全種類
- unitPoints全rounding
- rateFraction全rounding
- exactの端数拒否
- fixedPoints
- threshold境界
- tieredの境界、重複、空白
- none
- replacement
- suppression
- suppressTags
- exclusive groupの決定性
- dependency
- cap未対応値の拒否
- mirrorのraw/final切替
- mirrorの端数拒否
- mirror循環
- 入力順序非依存
- atomic failure
- traceの順序と不変性
- 結果Map/Listの不変性
- 負の取引金額拒否
- 安全限界
- architecture check

## 28. 完了条件

- dart formatが成功する
- 変更対象のdart analyzeが成功する
- PR-08単体テストが成功する
- 全flutter testが成功する
- Architecture Checkが成功する
- git diff --checkが成功する
- UTF-8 BOMが存在しない
- 生成ファイルがHEADと一致する
- stage、commit、pushはレビュー完了まで行わない
### Mirror orchestration semantics

- A mirror rule evaluates its own exclusions, selectors, date, validity period,
  and condition before resolving its source.
- `inheritExclusions` propagates only an explicit `excluded` source result.
- `inheritEligibility` propagates source selector, validity, date, and
  condition eligibility outcomes. Explicit exclusion remains controlled by
  `inheritExclusions`.
- `useFinalSourceAmount: false` uses the source calculation before replacement,
  suppression, dependency, exclusive-group, and future cap effects.
- `useFinalSourceAmount: true` uses the source result after those effects.
  A final ineligible source contributes zero points.
- A source whose numeric points are unavailable produces an unavailable mirror
  result with `mirrorSourceMissing`.
- Mirror chains are resolved by rule ID with an explicit iterative stack and
  memoized independently of input order. This avoids call-stack growth for
  long chains. Mirror cycles and missing IDs are rejected by rule-set
  validation.
- Exclusive-group comparison uses provisional pre-exclusive mirror points.
  Final mirror values are resolved after exclusive-group winners are known.
- Mirror multiplication uses exact rational arithmetic. Non-integer results and
  invalid rule definitions remain structured failures and are not converted to
  zero or unknown results.
### Controller and dependency final-state semantics

- A replacement controller contributes relations only if it remains eligible
  and is not itself replaced.
- A suppression controller contributes relations only if it remains eligible,
  is not replaced, and is not itself suppressed.
- Replacement and suppression controller graphs are evaluated independently of
  input order.
- Suppression cycles, including cycles created through tag expansion, are
  rejected as `calculationRuleInvalid`.
- Dependency propagation runs before exclusive-group comparison and again
  after exclusive-group losers are known.
- If an exclusive-group loser is a dependency target, its dependents become
  `dependencyNotSatisfied`. The exclusive group is not reselected afterward;
  this avoids oscillating winner/dependency states.
### Final result boundary semantics

- `RewardRuleSetEvaluator.evaluate` remains the backward-compatible per-rule
  result boundary.
- `RewardRuleSetEvaluator.evaluateResult` returns an immutable final result
  containing `pointsByProgram`, deterministically ordered `ruleResults`, and
  one final trace record per rule.
- `pointsByProgram` sums final, numerically available rule points whose
  `outputPointProgramId` is non-null. Unavailable results do not invent or
  contribute points.
- Ineligible rules contribute their explicit zero points when they declare an
  output program.
- Trace order is identical to validator order and therefore does not depend on
  caller input order.
- For the supported transaction scope, `amountBefore` is zero and
  `amountAfter` is the current transaction amount.
- Because non-null caps remain rejected in PR-08, `pointsBeforeCap` and
  `pointsAfterCap` are equal. The separate fields preserve the future cap
  boundary.
- Mirror trace entries record the referenced `sourceRuleId`.
- Trace details contain only safe structural metadata and must not contain
  payment credentials, account identifiers, authentication values, or other
  secrets.
- Result maps, result lists, trace lists, reason-code lists, and trace detail
  maps are defensively copied and unmodifiable.
- The public result boundary rejects traces above 100,000 records with
  `calculationOverflow`.

# BESTpay v2 用語・列挙値正本



文書ID：BP-TERMINOLOGY-001

文書バージョン：1.0.0

基準日：2026-09-18

ステータス：active

authorityLevel：normative



本書は「BESTpay v2 全115文書 統合調整・整合性修正仕様書 BP-DOC-INTEGRATION-001」に従う。



本書と統合調整仕様書が競合する場合、統合調整仕様書を優先する。



\---



\## 1. 製品名称



| 用途 | 正式表記 |

|---|---|

| 製品名 | BESTpay |

| 対象バージョン | BESTpay v2 |

| 旧版 | BESTpay v1 |

| 旧文書内名称 | 旧称「Maxpay」 |

| GitHubリポジトリ | kiryu4040/BESTpay |



製品表示名、applicationId、Android namespace、Bundle ID、リリース署名は別概念として扱う。



applicationId、Android namespace、Bundle ID、リリース署名は、既存配布版との照合が完了するまで変更しない。



\---



\## 2. 主要ドメイン用語



| 日本語 | コード上の正本名 | 定義 |

|---|---|---|

| 決済手段 | PaymentInstrument | クレジットカード、デビットカード、QR決済等の支払い主体 |

| 支払いモード | PaymentMode | 同じ決済手段内のcredit、debit、pointPay、addedCard等 |

| 決済経路 | PaymentRoute | physicalCard、mobileContactless、onlineCard等の伝達経路 |

| 資金経路 | FundingRelation | チャージ元、引落元、資金供給元等との関係 |

| 還元ルール | RewardRule | ポイント等を計算する期間付きルール |

| 支払いプラン | PaymentPlan | 決済手段、モード、経路、資金経路等の計算対象組合せ |

| ポイント数 | PointAmount | 円換算前の整数ポイント数 |

| ポイント価値 | PointValue | ポイントを円換算した値 |

| 期間利用状態 | UsagePeriodState | 月間、年間、ユーザー固有期間の利用額、上限、ボーナス状態 |

| 取引記録 | TransactionRecord | 任意保存する非機密の利用記録 |

| お気に入り | Favorite | merchant、instrument、paymentPlan、searchPresetへの参照 |

| 情報源 | Source | 公式規約、FAQ、商品ページ、発表等の根拠 |

| カタログ | Catalog | 商品、店舗、ルール、情報源等の配布可能なマスターデータ |



PaymentInstrument、PaymentMode、PaymentRoute、FundingRelationを同一概念として扱わない。



\---



\## 3. 金額・ポイント・率



\### 3.1 MoneyYen



整数円を表現する。



共通値オブジェクトでは、返金、取消、調整、差分のため負数を許可する。



通常購入金額を0以上に制限する責務は、Domainモデルに置く。



\### 3.2 PointAmount



整数ポイント数を表現する。



共通値オブジェクトでは、取消、調整、差分のため負数を許可する。



通常付与ポイントを0以上に制限する責務は、Domainモデルに置く。



\### 3.3 PointValue



ポイントの円換算価値を表現する。



PointAmountとPointValueを同一視しない。



\### 3.4 Rational



分子と分母による正確な有理数を表現する。



```text

numerator

denominator

```



分母0を禁止する。



\### 3.5 Rate



内部表現にRationalを使用する。



例：



```text

0.5%  = 1 / 200

1.0%  = 1 / 100

1.25% = 1 / 80

1.5%  = 3 / 200

```



金額、ポイント、率の正本計算に`double`を使用しない。



\---



\## 4. 日付・時刻



| 正本名 | 定義 |

|---|---|

| transactionAt | 利用または決済が行われた日時 |

| postingAt | 売上確定データに記録された日時 |

| settlementDataReceivedAt | 制度運営者へ売上確定データが到着した日時 |

| billingAt | 請求日時 |

| validFrom | 有効期間の開始日。範囲に含む |

| validUntilExclusive | 有効期間の終了日。範囲に含まない |

| periodStart | 集計期間の開始日 |

| periodEndExclusive | 集計期間の終了日。範囲に含まない |

| generatedAt | ファイル生成日時 |

| lastVerifiedAt | 情報源または制度を最後に確認した日 |

| updatedAt | ユーザーデータ等の最終更新日時 |



制度日付は次の形式とする。



```text

YYYY-MM-DD

```



日時はタイムゾーン付きISO 8601とする。



日本国内制度の既定タイムゾーン：



```text

Asia/Tokyo

```



内部処理の現在時刻はUTCを基準とし、制度日付へ変換するときはタイムゾーンを明示する。



\---



\## 5. 有効期間



有効期間は半開区間とする。



```text

\[validFrom, validUntilExclusive)

```



判定：



```text

validFrom <= date

date < validUntilExclusive

```



終了日未定：



```text

validUntilExclusive = null

```



汎用ValidityPeriodでは空期間を表現できる。



```text

validFrom == validUntilExclusive

```



ただし、activeなカタログ項目では空期間をerrorとする。



\---



\## 6. dateBasis



使用可能な値：



```text

transactionDate

postingDate

settlementDataReceivedDate

billingDate

entryDate

campaignRegistrationDate

periodEndDate

```



必要な日時が未入力の場合、transactionDateへ自動代替しない。



V NEOBANKの2026年11月改定は次を使用する。



```text

settlementDataReceivedDate

```



\---



\## 7. 条件状態



型名：



```text

TriState

```



保存値：



```text

satisfied

notSatisfied

unknown

notApplicable

```



| 値 | 意味 |

|---|---|

| satisfied | 条件を満たすことが確認済み |

| notSatisfied | 条件を満たさないことが確認済み |

| unknown | 情報不足等により判定不能 |

| notApplicable | その対象には条件自体が適用されない |



`unknown`を暗黙にtrueまたはfalseへ変換しない。



`notApplicable`を`unknown`として保存しない。



enum indexを保存しない。



\---



\## 8. confidence



使用可能な値：



```text

confirmed

estimated

conditional

unknown

ineligible

```



| 値 | 意味 |

|---|---|

| confirmed | 必要条件と根拠が確認済み |

| estimated | カテゴリ推定等を含む |

| conditional | 未確認条件を満たした場合に成立 |

| unknown | 計算結果または価値を判定できない |

| ineligible | 対象外であることが確定 |



カテゴリ名だけで加盟店を推定した場合は、原則`estimated`とする。



\---



\## 9. PaymentMode.modeType



使用可能な値：



```text

credit

debit

pointPay

addedCard

prepaidBalance

```



最上位仕様に従い、正本は`pointPay`とする。



次の表記は使用しない。



```text

pointPayment

```



\---



\## 10. PaymentRoute.routeType



基本値：



```text

physicalCard

mobileContactless

onlineCard

qrCode

electronicMoney

mobileOrder

```



カード現物によるタッチ決済と、スマートフォンによるタッチ決済を同一経路として扱わない。



個別経路IDの例：



```text

physical\_card

visa\_contactless\_card

visa\_contactless\_mobile

mastercard\_contactless\_card

mastercard\_contactless\_mobile

quicpay\_mobile

online\_card\_payment

mobile\_order

```



\---



\## 11. RewardRule.ruleKind



使用可能な値：



```text

baseReward

merchantBonus

categoryBonus

routeBonus

fundingBonus

loyaltyReward

thresholdBonus

campaignBonus

mirrorReward

suppression

replacement

```



\---



\## 12. RewardRule.calculation.type



使用可能な値：



```text

unitPoints

rateFraction

fixedPoints

mirror

thresholdBonus

tiered

none

```



`rateFraction`は分子と分母で保存する。



小数やパーセント文字列を計算値の正本にしない。



\---



\## 13. RoundingMode



使用可能な値：



```text

towardZero

floor

ceiling

halfAwayFromZero

halfToEven

exact

```



| 値 | 意味 |

|---|---|

| towardZero | 0方向へ丸める |

| floor | 負の無限大方向へ丸める |

| ceiling | 正の無限大方向へ丸める |

| halfAwayFromZero | 中間値を0から遠い方向へ丸める |

| halfToEven | 中間値を偶数へ丸める |

| exact | 端数が発生した場合にエラー |



enum indexを保存しない。



丸め方式を省略しない。



\---



\## 14. aggregation.scope



使用可能な値：



```text

transaction

billingMonth

calendarMonth

membershipYear

programYear

userSpecificPeriod

```



| 値 | 意味 |

|---|---|

| transaction | 取引単位 |

| billingMonth | 請求月単位 |

| calendarMonth | 暦月単位 |

| membershipYear | 入会日等を基準とする年次期間 |

| programYear | 制度固有の年次期間 |

| userSpecificPeriod | ユーザー条件から算出する個別期間 |



\---



\## 15. Favorite.entityType



使用可能な値：



```text

merchant

instrument

paymentPlan

searchPreset

```



一意キー：



```text

(entityType, entityId)

```



\---



\## 16. DocumentStatus



仕様書と文書台帳で使用する。



```text

draft

review

active

deprecated

superseded

archived

```



自由記述だけで文書状態を表現しない。



\---



\## 17. CatalogItemStatus



PaymentInstrument、PaymentMode、PaymentRoute、RewardRule等で使用する。



```text

draft

review

active

suspended

deprecated

ended

archived

```



| 値 | 意味 |

|---|---|

| draft | 調査中または一次情報不足 |

| review | 内容確認中 |

| active | 通常計算へ使用可能 |

| suspended | 一時的に通常計算から除外 |

| deprecated | 後継への移行対象 |

| ended | 有効期間終了 |

| archived | 履歴保存専用 |



通常ランキングへ使用できるのは、原則`active`だけとする。



\---



\## 18. authorityLevel



使用可能な値：



```text

normative

supporting

informative

historical

generated

```



| 値 | 意味 |

|---|---|

| normative | 実装を拘束する正本 |

| supporting | 正本を補足する設計または説明 |

| informative | 調査記録または参考資料 |

| historical | 過去仕様 |

| generated | 正本から生成された成果物 |



同じ領域に複数のnormative正本を置かない。



\---



\## 19. Source.sourceType



使用可能な値：



```text

officialTerms

officialFaq

officialProductPage

officialCampaignPage

officialNewsRelease

officialAppNotice

secondaryArticle

userReport

```



確定計算へ使用するactiveルールは、原則としてofficial系のprimary情報源を必要とする。



secondaryArticleまたはuserReportだけの制度は、draftまたはunverifiedとして扱う。



\---



\## 20. Source.accessStatus



使用可能な値：



```text

available

changed

unavailable

redirected

archived

unknown

```



公式ページの本文が変更された場合、既存Sourceを削除しない。



変更前のcontentHashを履歴として保持する。



\---



\## 21. Source.reliability



使用可能な値：



```text

primary

secondary

unverified

```



\---



\## 22. matchConfidence



使用可能な値：



```text

exactMerchant

merchantGroup

categoryOnly

userSelected

unknown

```



`categoryOnly`は原則として、計算結果のconfidenceを`estimated`にする。



\---



\## 23. rankingMode



使用可能な値：



```text

confirmedValue

effectiveRate

userValue

annualAverageRate

marginalRate

conditionalMaximum

fewestSteps

```



既定値：



```text

confirmedValue

```



`nominalRate`は広告表示用であり、既定ランキングへ使用しない。



\---



\## 24. エラー重大度



使用可能な値：



```text

fatal

error

warning

info

```



| 値 | 意味 |

|---|---|

| fatal | カタログ全体を使用不能とする |

| error | 対象レコードまたは対象ルールを無効化する |

| warning | 処理を継続できるが通知を必要とする |

| info | 動作説明、履歴、補助情報 |



\---



\## 25. Source以外の情報状態



制度またはカタログ項目について、一次情報が不足する場合は`active`へ昇格させない。



使用候補：



```text

draft

review

active

suspended

deprecated

ended

archived

```



`unverified`はSource.reliability等の検証状態として扱い、DocumentStatusと混同しない。



\---



\## 26. ID変更



ID変更は次を経由する。



```text

id\_migrations.json

```



移行種別：



```text

rename

merge

split

remove

```



規則：



\- renameは自動移行可能

\- mergeは参照先の意味が維持される場合のみ自動移行可能

\- splitは原則ユーザー確認

\- removeはneedsReview

\- 廃止IDを新しい別概念へ再利用しない

\- 移行不能データを黙って削除しない



\---



\## 27. reasonCode



\### 適用関連



```text

ruleApplied

conditionSatisfied

merchantMatched

categoryMatched

routeMatched

periodMatched

```



\### 非適用関連



```text

instrumentMismatch

modeMismatch

routeMismatch

merchantMismatch

categoryMismatch

outsideValidPeriod

conditionNotSatisfied

conditionUnknown

notApplicable

explicitlyExcluded

suppressedByRule

replacedByRule

lostExclusiveComparison

capReached

catalogDisabled

ruleInactive

```



\### 不確実性関連



```text

postingDateUnknown

settlementDataReceivedDateUnknown

periodSpendUnknown

merchantEligibilityUnknown

pointValueUnknown

conditionStateUnknown

capConsumptionUnknown

staleSource

categoryOnlyMatch

```



\### エラー関連



```text

invalidRequest

missingReference

invalidCalculationDefinition

divisionByZero

cyclicMirrorReference

integerOverflowPrevented

unsupportedRuleType

catalogIntegrityFailure

```



\---



\## 28. バックアップ対象外



次をバックアップ、TransactionRecord、計算トレース、ログへ保存しない。



```text

カード番号

セキュリティコード

暗証番号

ログインID

パスワード

銀行口座番号

APIトークン

Cookie

セッション情報

```



\---



\## 29. 廃止または置換する表記



| 廃止・旧表記 | 正本 |

|---|---|

| Maxpay | BESTpay |

| Maxpay v2 | BESTpay v2 |

| pointPayment | pointPay |

| endedAt | validUntilExclusiveまたはperiodEndExclusive |

| validUntil | validUntilExclusive |

| 固定還元率 | RewardRule |

| 最大還元率を計算値として保存 | displayClaim |

| enum index保存 | 安定文字列保存 |

| 売上確定日と売上到着日を同一視 | postingAtとsettlementDataReceivedAtを分離 |

| ポイント数と円価値を同一視 | PointAmountとPointValueを分離 |

| カード本体へ還元率を保存 | 期間付きRewardRuleへ保存 |

| 旧ルールを上書き | 新ルール追加と旧ルール履歴保持 |



\---



\## 30. 正本の優先順位



1\. BP-DOC-INTEGRATION-001

2\. activeかつnormativeの文書

3\. 公式規約、公式FAQ、公式商品ページ、公式発表

4\. activeかつsupportingの文書

5\. 実装コード

6\. 自動テスト

7\. draft文書

8\. historical、superseded、archived文書



以上。

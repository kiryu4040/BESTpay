# PR-09 Period Aggregation Decisions

- Document ID: `BP-PR09-PERIOD-AGGREGATION-DECISIONS-001`
- Status: Initial implementation slice
- Parent commit: `655aa66a83e31ea7e9d5bfacb3050edb75ea62b8`
- Branch: `feature/pr-09-period-aggregation`

This document records sequential implementation slices. Earlier sections
describe the boundary at the time that slice was completed; later sections
supersede earlier deferred-work statements where they explicitly implement the
deferred behavior. Section 17 describes the final PR-09 integration boundary.

## 1. Slice 1 scope (historical)

This slice introduces the immutable period-aggregation input boundary required
by later reward-rule evaluation work.

It adds:

- `PeriodAggregationSnapshot`
- `PeriodDataConfidence`
- an immutable snapshot map on `RewardEvaluationInput`
- lookup by aggregation key
- validation and immutability tests

This slice does not enable period aggregation in
`RewardRuleSetValidator` and does not change reward calculation behavior.

## 2. Snapshot values

A period snapshot contains:

- `periodSpendBefore`
- `periodSpendAfter`
- `pointsBefore`
- `pointsAfter`
- `currentIncrement`
- `confidence`

The before and after values make the transaction boundary explicit.
`currentIncrement` must equal `pointsAfter - pointsBefore`.

## 3. Negative increments

`currentIncrement` may be negative when a reversal, refund, or correction
reduces the period result.

The accumulated `pointsBefore` and `pointsAfter` values remain non-negative in
this slice. A negative accumulated total is rejected at the public boundary.

Period spend totals also remain non-negative. A refund may reduce
`periodSpendAfter` relative to `periodSpendBefore`, but may not produce a
negative period total.

## 4. Confidence

`PeriodDataConfidence` has four values:

- `exact`
- `userEntered`
- `estimated`
- `unknown`

Confidence describes the quality of the supplied period data. This slice stores
the value without changing reward eligibility or reward calculation.

## 5. Aggregation keys

`RewardEvaluationInput.periodAggregationSnapshots` is keyed by `StableId`.

For a period-aware rule, the key is expected to correspond to the rule's
`RewardAggregation.aggregationKey`. The map is defensively copied and exposed
as an unmodifiable map.

A missing key returns `null`. Error/result mapping for required missing period
data belongs to the later evaluation slice.

## 6. Compatibility

The new `RewardEvaluationInput` constructor argument is optional and defaults
to an empty map.

Existing callers therefore remain source-compatible. The existing
`thresholdPeriodSnapshot` field is retained without changing its behavior.

## 7. Immutability

`PeriodAggregationSnapshot` exposes final fields and has no mutation methods.

`RewardEvaluationInput` copies the supplied period snapshot map before wrapping
it as unmodifiable. Mutating the caller-owned map after construction cannot
change the evaluation input.

## 8. Deferred work after Slice 1 (historical)

The following work is intentionally deferred:

- deriving aggregation keys
- deriving period start and end boundaries
- billing-month and calendar-month resolution
- enabling period scopes in `RewardRuleSetValidator`
- applying `incrementalAward`
- fixed, threshold, tiered, and mirror integration
- missing-period-data result mapping
- cap integration
- persistence and SQLite storage
- legacy adapters
- transaction-history integration
- UI integration

The deferred features must consume this immutable boundary rather than adding
mutable state to the reward calculation engine.
## 9. Period aggregation evaluation

`PeriodAggregationEvaluator` is a pure domain service. It selects an immutable
snapshot using `RewardAggregation.aggregationKey` and does not derive, mutate,
or persist period state.

The evaluator is used only for non-transaction aggregation scopes.
Transaction-scoped rules continue to use the existing transaction calculation
path.

## 10. Incremental award semantics

This slice supports only `incrementalAward: true`.

When period spend satisfies `periodMinimumEligibleSpend`, the result is
`snapshot.currentIncrement`. The snapshot constructor guarantees that this
value equals `pointsAfter - pointsBefore`.

`incrementalAward: false` is rejected because period-end one-time award
semantics have not yet been defined.

## 11. Period confidence mapping

Period data confidence maps to reward confidence as follows:

- `exact` maps to `confirmed`
- `userEntered` maps to `estimated`
- `estimated` maps to `estimated`
- `unknown` produces an unavailable result with `periodStateUnknown`

A missing keyed snapshot produces an unavailable result with
`periodStateMissing`.

## 12. Minimum eligible spend

When `periodSpendAfter` is below `periodMinimumEligibleSpend`, the evaluator
returns zero points with `periodMinimumSpendNotMet`.

The minimum is evaluated against the externally supplied after-state. The
evaluator does not infer period boundaries or add the current transaction
amount to the snapshot.

## 13. Negative increments

The snapshot model may represent a negative increment for reversal and
correction state.

The current reward result boundary permits only non-negative calculated
points. Therefore, a negative incremental result is rejected with a structured
`calculationInputInvalid` error until adjustment-result semantics are defined.

## 14. Slice 2 validator and rule-evaluator boundary (historical)

This slice does not yet relax `RewardRuleSetValidator` and does not connect
period evaluation to `RewardRuleEvaluator`.

Those integrations belong to the next slice, after this pure evaluator and its
failure semantics are verified independently.

## 15. Slice 3A direct rule-evaluator integration

`RewardRuleEvaluator` routes non-transaction aggregation scopes to
`PeriodAggregationEvaluator` after selector, exclusion, date, and condition
eligibility checks have succeeded.

Transaction-scoped rules retain the existing `RewardCalculationEvaluator`
path, including the legacy threshold snapshot behavior. The new routing does
not alter `evaluateEligibility`.

Structured failures and unavailable period results are propagated through
`RewardRuleEvaluationResult.fromCalculation` without converting them to
transaction-calculation outcomes.

`RewardRuleSetValidator` continues to reject period scopes in this slice.
Rule-set integration and validator relaxation remain deferred so that a
validated configuration cannot be accepted before orchestration supports it.

## 16. Slice 3B explicit period boundaries

Every `PeriodAggregationSnapshot` has a required `periodStart` and
`periodEndExclusive`, both represented by `CalculationDate`.

The represented period is the non-empty half-open interval
`[periodStart, periodEndExclusive)`. Construction rejects equal or reversed
boundaries. The start date is included and the end date is excluded.

The snapshot exposes `contains` for boundary-safe membership checks.

This slice does not derive boundaries from `RewardAggregationScope`. Calendar
month, billing month, membership year, program year, and user-specific period
resolution require a later timezone-aware period resolver. Until that resolver
exists, supplied boundaries are treated as externally resolved immutable
state.

Scope-to-boundary consistency, persistence, and transaction-history derivation
remain deferred. The rule-set validator is not relaxed in this slice.

## 17. Validator and rule-set integration

The rule-set validator accepts non-transaction aggregation scopes only when an
aggregation key is present, condition evaluation timing is `transaction`, and
`incrementalAward` is true. The `RewardAggregation` model itself rejects a
negative period minimum before validator evaluation.

Transaction-scoped validation remains unchanged: aggregation keys, non-zero
period minimums, and incremental awards remain unsupported.

Mirror calculations involving a period-scoped mirror or period-scoped source
are rejected until period mirror semantics are defined.

The rule-set evaluator routes ordinary non-transaction rules to
`PeriodAggregationEvaluator`. Existing replacement, suppression, dependency,
and exclusive-group ordering remains eligibility-driven and deterministic.

Calculation availability does not retroactively change the earlier eligibility
result. Therefore, a period rule whose selectors, dates, and conditions are
eligible still replaces or suppresses its configured targets when its snapshot
is missing or has unknown confidence. Such a rule also satisfies an
eligibility-based dependency. The controller or prerequisite itself remains
unavailable and awards no points. This preserves the pre-existing rule-set
orchestration contract rather than making stacking depend on transient data
availability.

Unavailable period state does not participate in final exclusive-group winner
selection. If a group contains an available candidate and an unavailable
period candidate, no loser is selected from an unresolved comparison; the
available candidate remains applied and the period candidate remains
unavailable.

For period rules with an available snapshot, trace `amountBefore` and
`amountAfter` are the snapshot's `periodSpendBefore` and `periodSpendAfter`.
Trace details include the aggregation key and half-open period boundaries.
When period state is missing, both trace amounts are zero rather than being
misreported as transaction amounts.

Period derivation, persistence, negative adjustment results, period-end awards,
caps, and period mirror calculations remain deferred.

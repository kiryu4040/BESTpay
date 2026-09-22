/// Stable diagnostic reason codes produced by reward evaluation.
///
/// These values are machine-readable identifiers, not user-facing messages.
/// Persist [value], never the enum index.
enum RewardReasonCode {
  applied('applied'),
  selectorMismatch('selectorMismatch'),
  excluded('excluded'),
  outsideValidityPeriod('outsideValidityPeriod'),
  missingDateBasis('missingDateBasis'),
  conditionNotSatisfied('conditionNotSatisfied'),
  conditionUnknown('conditionUnknown'),
  replaced('replaced'),
  suppressed('suppressed'),
  exclusiveGroupLost('exclusiveGroupLost'),
  dependencyNotSatisfied('dependencyNotSatisfied'),
  periodStateMissing('periodStateMissing'),
  capApplied('capApplied'),
  mirrorSourceMissing('mirrorSourceMissing'),
  invalidRule('invalidRule'),
  noRewardCalculation('noRewardCalculation'),
  thresholdNotCrossed('thresholdNotCrossed'),
  thresholdAwardLimitReached('thresholdAwardLimitReached');

  const RewardReasonCode(this.value);

  final String value;
}

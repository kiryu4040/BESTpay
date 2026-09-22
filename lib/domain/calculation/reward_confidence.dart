/// Stable confidence values produced by the reward calculation engine.
///
/// Persist [value], never the enum index.
enum RewardConfidence {
  confirmed('confirmed'),
  estimated('estimated'),
  conditional('conditional'),
  unknown('unknown'),
  ineligible('ineligible');

  const RewardConfidence(this.value);

  final String value;
}

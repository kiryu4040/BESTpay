/// Lifecycle status shared by catalog records.
enum CatalogItemStatus {
  draft('draft'),
  unverified('unverified'),
  active('active'),
  inactive('inactive'),
  deprecated('deprecated'),
  superseded('superseded'),
  historical('historical'),
  archived('archived');

  const CatalogItemStatus(this.value);

  final String value;
}

/// A payment mode within one payment instrument.
enum PaymentModeType {
  credit('credit'),
  debit('debit'),
  pointPay('pointPay'),
  addedCard('addedCard'),
  prepaidBalance('prepaidBalance');

  const PaymentModeType(this.value);

  final String value;
}

/// How a condition value is verified.
enum ConditionVerificationMethod {
  userInput('userInput'),
  systemCalculated('systemCalculated'),
  transactionDerived('transactionDerived'),
  periodStateDerived('periodStateDerived'),
  officialAccountDerived('officialAccountDerived'),
  manualDocumentCheck('manualDocumentCheck');

  const ConditionVerificationMethod(this.value);

  final String value;
}

/// Comparison operation used by a condition expression.
enum ComparisonOperator {
  equals('equals'),
  notEquals('notEquals'),
  greaterThan('greaterThan'),
  greaterThanOrEqual('greaterThanOrEqual'),
  lessThan('lessThan'),
  lessThanOrEqual('lessThanOrEqual'),
  inSet('in'),
  notInSet('notIn');

  const ComparisonOperator(this.value);

  final String value;
}

/// Stable ID migration operation.
enum IdMigrationType {
  rename('rename'),
  merge('merge'),
  split('split'),
  remove('remove');

  const IdMigrationType(this.value);

  final String value;
}

/// Kind of evidence represented by a catalog source.
enum CatalogSourceType {
  officialTerms('officialTerms'),
  officialFaq('officialFaq'),
  officialProductPage('officialProductPage'),
  officialCampaignPage('officialCampaignPage'),
  officialNewsRelease('officialNewsRelease'),
  officialAppNotice('officialAppNotice'),
  secondaryArticle('secondaryArticle'),
  userReport('userReport');

  const CatalogSourceType(this.value);

  final String value;
}

/// Current accessibility state of a catalog source.
enum CatalogSourceAccessStatus {
  accessible('accessible'),
  changed('changed'),
  unavailable('unavailable'),
  archived('archived');

  const CatalogSourceAccessStatus(this.value);

  final String value;
}

/// Evidence reliability classification.
enum CatalogSourceReliability {
  primary('primary'),
  secondary('secondary'),
  userReported('userReported'),
  unverified('unverified');

  const CatalogSourceReliability(this.value);

  final String value;
}

/// Semantic role of a reward rule.
enum RewardRuleKind {
  baseReward('baseReward'),
  merchantBonus('merchantBonus'),
  categoryBonus('categoryBonus'),
  routeBonus('routeBonus'),
  fundingBonus('fundingBonus'),
  loyaltyReward('loyaltyReward'),
  thresholdBonus('thresholdBonus'),
  campaignBonus('campaignBonus'),
  mirrorReward('mirrorReward'),
  suppression('suppression'),
  replacement('replacement');

  const RewardRuleKind(this.value);

  final String value;
}

/// Scope over which eligible transactions are aggregated.
enum RewardAggregationScope {
  transaction('transaction'),
  billingMonth('billingMonth'),
  calendarMonth('calendarMonth'),
  membershipYear('membershipYear'),
  programYear('programYear'),
  userSpecificPeriod('userSpecificPeriod');

  const RewardAggregationScope(this.value);

  final String value;
}

/// Date used to determine whether a reward rule applies.
enum RewardDateBasis {
  transactionDate('transactionDate'),
  postingDate('postingDate'),
  settlementDataReceivedDate('settlementDataReceivedDate'),
  billingDate('billingDate'),
  entryDate('entryDate'),
  campaignRegistrationDate('campaignRegistrationDate'),
  periodEndDate('periodEndDate');

  const RewardDateBasis(this.value);

  final String value;
}

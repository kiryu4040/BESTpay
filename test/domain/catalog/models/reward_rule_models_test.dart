import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/rounding_mode.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/validity_period.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/condition_models.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RewardRule schema enums', () {
    test('rule kinds use stable schema values', () {
      expect(
        RewardRuleKind.values.map((value) => value.value),
        <String>[
          'baseReward',
          'merchantBonus',
          'categoryBonus',
          'routeBonus',
          'fundingBonus',
          'loyaltyReward',
          'thresholdBonus',
          'campaignBonus',
          'mirrorReward',
          'suppression',
          'replacement',
        ],
      );
    });

    test('aggregation scopes use stable schema values', () {
      expect(
        RewardAggregationScope.values.map((value) => value.value),
        <String>[
          'transaction',
          'billingMonth',
          'calendarMonth',
          'membershipYear',
          'programYear',
          'userSpecificPeriod',
        ],
      );
    });

    test('date bases use stable schema values', () {
      expect(
        RewardDateBasis.values.map((value) => value.value),
        <String>[
          'transactionDate',
          'postingDate',
          'settlementDataReceivedDate',
          'billingDate',
          'entryDate',
          'campaignRegistrationDate',
          'periodEndDate',
        ],
      );
    });
  });

  group('SelectorSet', () {
    test('defensively copies all selector lists', () {
      final instrumentIds = <StableId>[_id('instrument_one')];
      final selector = SelectorSet(
        instrumentIds: instrumentIds,
        modeIds: <StableId>[_id('mode_one')],
        routeIds: <StableId>[_id('route_one')],
        fundingRelationIds: <StableId>[_id('funding_one')],
        merchantIds: <StableId>[_id('merchant_one')],
        merchantGroupIds: <StableId>[_id('group_one')],
        categoryIds: <StableId>[_id('category_one')],
        brandIds: <StableId>[_id('brand_one')],
        locationIds: <StableId>[_id('location_one')],
        transactionTags: <StableId>[_id('tag_one')],
      );

      instrumentIds.add(_id('instrument_two'));

      expect(
        selector.instrumentIds,
        <StableId>[_id('instrument_one')],
      );
      expect(
        () => selector.instrumentIds.add(_id('instrument_three')),
        throwsUnsupportedError,
      );
    });

    test('rejects duplicate selector IDs', () {
      final id = _id('instrument_one');

      expect(
        () => SelectorSet(
          instrumentIds: <StableId>[id, id],
          modeIds: const <StableId>[],
          routeIds: const <StableId>[],
          fundingRelationIds: const <StableId>[],
          merchantIds: const <StableId>[],
          merchantGroupIds: const <StableId>[],
          categoryIds: const <StableId>[],
          brandIds: const <StableId>[],
          locationIds: const <StableId>[],
          transactionTags: const <StableId>[],
        ),
        throwsArgumentError,
      );
    });
  });

  group('RewardCalculation', () {
    test('represents all seven calculation variants', () {
      final variants = <RewardCalculation>[
        UnitPointsRewardCalculation(
          amountUnit: const MoneyYen(200),
          pointsPerUnit: const PointAmount(1),
          rounding: RoundingMode.floor,
        ),
        RateFractionRewardCalculation(
          rate: _rational(1, 100),
          rounding: RoundingMode.halfToEven,
        ),
        const FixedPointsRewardCalculation(PointAmount(10)),
        MirrorRewardCalculation(
          sourceRuleId: _id('reward_source'),
          multiplier: _rational(2, 1),
          inheritEligibility: true,
          inheritExclusions: true,
          useFinalSourceAmount: false,
        ),
        ThresholdBonusRewardCalculation(
          thresholdAmount: const MoneyYen(1000),
          bonusPoints: const PointAmount(100),
          maxAwardsPerPeriod: 1,
        ),
        TieredRewardCalculation(<RewardTier>[
          RewardTier(
            minimumAmount: const MoneyYen(0),
            maximumAmountExclusive: const MoneyYen(1000),
            calculation: RateFractionRewardCalculation(
              rate: _rational(1, 100),
              rounding: RoundingMode.floor,
            ),
          ),
        ]),
        const NoRewardCalculation(),
      ];

      expect(variants.length, 7);
      expect(variants[0], isA<UnitPointsRewardCalculation>());
      expect(variants[1], isA<RateFractionRewardCalculation>());
      expect(variants[2], isA<FixedPointsRewardCalculation>());
      expect(variants[3], isA<MirrorRewardCalculation>());
      expect(variants[4], isA<ThresholdBonusRewardCalculation>());
      expect(variants[5], isA<TieredRewardCalculation>());
      expect(variants[6], isA<NoRewardCalculation>());
    });

    test('enforces positive unit and award-count constraints', () {
      expect(
        () => UnitPointsRewardCalculation(
          amountUnit: const MoneyYen(0),
          pointsPerUnit: const PointAmount(1),
          rounding: RoundingMode.floor,
        ),
        throwsArgumentError,
      );

      expect(
        () => ThresholdBonusRewardCalculation(
          thresholdAmount: const MoneyYen(0),
          bonusPoints: const PointAmount(1),
          maxAwardsPerPeriod: 0,
        ),
        throwsArgumentError,
      );
    });

    test('requires at least one tier and freezes the tier list', () {
      expect(
        () => TieredRewardCalculation(const <RewardTier>[]),
        throwsArgumentError,
      );

      final tiers = <RewardTier>[
        RewardTier(
          minimumAmount: const MoneyYen(0),
          maximumAmountExclusive: null,
          calculation: const FixedPointsRewardCalculation(
            PointAmount(10),
          ),
        ),
      ];

      final calculation = TieredRewardCalculation(tiers);
      tiers.add(
        RewardTier(
          minimumAmount: const MoneyYen(1000),
          maximumAmountExclusive: null,
          calculation: const FixedPointsRewardCalculation(
            PointAmount(20),
          ),
        ),
      );

      expect(calculation.tiers.length, 1);
      expect(
        () => calculation.tiers.add(calculation.tiers.first),
        throwsUnsupportedError,
      );
    });

    test('rejects unsupported nested tier calculations', () {
      expect(
        () => RewardTier(
          minimumAmount: const MoneyYen(0),
          maximumAmountExclusive: null,
          calculation: const NoRewardCalculation(),
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid amount boundaries', () {
      expect(
        () => RewardTier(
          minimumAmount: const MoneyYen(-1),
          maximumAmountExclusive: null,
          calculation: const FixedPointsRewardCalculation(
            PointAmount(1),
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => RewardTier(
          minimumAmount: const MoneyYen(0),
          maximumAmountExclusive: const MoneyYen(0),
          calculation: const FixedPointsRewardCalculation(
            PointAmount(1),
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Reward metadata', () {
    test('aggregation preserves typed scope and open string timing', () {
      final aggregation = RewardAggregation(
        scope: RewardAggregationScope.billingMonth,
        aggregationKey: _id('aggregation_one'),
        periodMinimumEligibleSpend: const MoneyYen(1000),
        conditionEvaluationTiming: 'periodEnd',
        incrementalAward: true,
      );

      expect(
        aggregation.scope,
        RewardAggregationScope.billingMonth,
      );
      expect(aggregation.conditionEvaluationTiming, 'periodEnd');
    });

    test('aggregation rejects invalid minimum and blank timing', () {
      expect(
        () => RewardAggregation(
          scope: RewardAggregationScope.transaction,
          aggregationKey: null,
          periodMinimumEligibleSpend: const MoneyYen(-1),
          conditionEvaluationTiming: 'transaction',
          incrementalAward: false,
        ),
        throwsArgumentError,
      );

      expect(
        () => RewardAggregation(
          scope: RewardAggregationScope.transaction,
          aggregationKey: null,
          periodMinimumEligibleSpend: const MoneyYen(0),
          conditionEvaluationTiming: '',
          incrementalAward: false,
        ),
        throwsArgumentError,
      );
    });

    test('stacking defensively copies rule relationships', () {
      final replaces = <StableId>[_id('reward_old')];

      final stacking = RewardStacking(
        policy: 'additive',
        exclusiveGroupId: null,
        replacesRuleIds: replaces,
        suppressesRuleIds: const <StableId>[],
        suppressesTags: const <StableId>[],
        dependsOnRuleIds: const <StableId>[],
        applicationOrder: 1,
      );

      replaces.add(_id('reward_other'));

      expect(stacking.replacesRuleIds, <StableId>[_id('reward_old')]);
      expect(
        () => stacking.replacesRuleIds.add(_id('reward_new')),
        throwsUnsupportedError,
      );
    });

    test('cap validates open strings and non-negative limit', () {
      final cap = RewardCap(
        capType: 'points',
        limit: 1000,
        periodType: 'calendarMonth',
        scopeKey: null,
        appliesTo: 'awardedPoints',
        overflowPolicy: 'discard',
      );

      expect(cap.limit, 1000);

      expect(
        () => RewardCap(
          capType: 'points',
          limit: -1,
          periodType: 'calendarMonth',
          scopeKey: null,
          appliesTo: 'awardedPoints',
          overflowPolicy: 'discard',
        ),
        throwsArgumentError,
      );

      expect(
        () => RewardCap(
          capType: '',
          limit: 0,
          periodType: 'calendarMonth',
          scopeKey: null,
          appliesTo: 'awardedPoints',
          overflowPolicy: 'discard',
        ),
        throwsArgumentError,
      );
    });
  });

  group('RewardRule', () {
    test('stores typed values and freezes source, tag, and note lists', () {
      final sourceIds = <StableId>[_id('source_one')];
      final tags = <StableId>[_id('tag_one')];
      final notes = <String>['verified'];

      final rule = _rule(
        conditionExpression: ConditionReferenceExpression(
          _id('condition_one'),
        ),
        sourceIds: sourceIds,
        tags: tags,
        notes: notes,
      );

      sourceIds.add(_id('source_two'));
      tags.add(_id('tag_two'));
      notes.add('changed');

      expect(rule.ruleKind, RewardRuleKind.baseReward);
      expect(rule.dateBasis, RewardDateBasis.transactionDate);
      expect(rule.timezone, 'Asia/Tokyo');
      expect(
        rule.conditionExpression,
        isA<ConditionReferenceExpression>(),
      );
      expect(rule.sourceIds, <StableId>[_id('source_one')]);
      expect(rule.tags, <StableId>[_id('tag_one')]);
      expect(rule.notes, <String>['verified']);
    });

    test('accepts nullable condition, output program, cap, and claim', () {
      final rule = _rule();

      expect(rule.conditionExpression, isNull);
      expect(rule.outputPointProgramId, isNull);
      expect(rule.cap, isNull);
      expect(rule.displayClaim, isNull);
    });

    test('rejects blank name, wrong timezone, and blank claim', () {
      expect(
        () => _rule(name: ''),
        throwsArgumentError,
      );
      expect(
        () => _rule(timezone: 'UTC'),
        throwsArgumentError,
      );
      expect(
        () => _rule(displayClaim: ''),
        throwsArgumentError,
      );
    });
  });
}

RewardRule _rule({
  String name = 'Base Reward',
  ConditionExpression? conditionExpression,
  String timezone = 'Asia/Tokyo',
  String? displayClaim,
  Iterable<StableId> sourceIds = const <StableId>[],
  Iterable<StableId> tags = const <StableId>[],
  Iterable<String> notes = const <String>[],
}) {
  return RewardRule(
    id: _id('reward_one'),
    name: name,
    description: '',
    ruleKind: RewardRuleKind.baseReward,
    selectors: _emptySelector(),
    exclusions: _emptySelector(),
    conditionExpression: conditionExpression,
    calculation: RateFractionRewardCalculation(
      rate: _rational(1, 100),
      rounding: RoundingMode.floor,
    ),
    outputPointProgramId: null,
    aggregation: RewardAggregation(
      scope: RewardAggregationScope.transaction,
      aggregationKey: null,
      periodMinimumEligibleSpend: const MoneyYen(0),
      conditionEvaluationTiming: 'transaction',
      incrementalAward: false,
    ),
    stacking: RewardStacking(
      policy: 'additive',
      exclusiveGroupId: null,
      replacesRuleIds: const <StableId>[],
      suppressesRuleIds: const <StableId>[],
      suppressesTags: const <StableId>[],
      dependsOnRuleIds: const <StableId>[],
      applicationOrder: 0,
    ),
    cap: null,
    validityPeriod: _period(),
    dateBasis: RewardDateBasis.transactionDate,
    timezone: timezone,
    displayClaim: displayClaim,
    sourceIds: sourceIds,
    lastVerifiedAt: _date('2026-09-20'),
    status: CatalogItemStatus.active,
    priority: 0,
    tags: tags,
    notes: notes,
  );
}

SelectorSet _emptySelector() {
  return SelectorSet(
    instrumentIds: const <StableId>[],
    modeIds: const <StableId>[],
    routeIds: const <StableId>[],
    fundingRelationIds: const <StableId>[],
    merchantIds: const <StableId>[],
    merchantGroupIds: const <StableId>[],
    categoryIds: const <StableId>[],
    brandIds: const <StableId>[],
    locationIds: const <StableId>[],
    transactionTags: const <StableId>[],
  );
}

StableId _id(String value) {
  final result = StableId.create(value);
  expect(result, isA<AppSuccess<StableId>>());
  return (result as AppSuccess<StableId>).value;
}

CalculationDate _date(String value) {
  final result = CalculationDate.parse(value);
  expect(result, isA<AppSuccess<CalculationDate>>());
  return (result as AppSuccess<CalculationDate>).value;
}

ValidityPeriod _period() {
  final result = ValidityPeriod.create(
    startsOn: _date('2026-01-01'),
    endsBefore: null,
  );
  expect(result, isA<AppSuccess<ValidityPeriod>>());
  return (result as AppSuccess<ValidityPeriod>).value;
}

Rational _rational(int numerator, int denominator) {
  final result = Rational.create(numerator, denominator);
  expect(result, isA<AppSuccess<Rational>>());
  return (result as AppSuccess<Rational>).value;
}

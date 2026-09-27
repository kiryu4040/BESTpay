import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/rounding_mode.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/validity_period.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/condition_models.dart';
import 'package:bestpay/domain/catalog/models/payment_instrument_models.dart';
import 'package:bestpay/domain/catalog/models/point_program_models.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:bestpay/domain/catalog/models/source_models.dart';

/// Converts raw catalog JSON documents into typed domain models.
///
/// The decoder never throws. A document that is missing, is not an object,
/// has no `items` array, or contains malformed records is reduced to the
/// records that could be decoded, so a broken catalog cannot stop startup.
final class JsonCatalogDecoder {
  const JsonCatalogDecoder({this.maximumConditionDepth = 20});

  /// Maximum nesting depth accepted for a condition expression.
  final int maximumConditionDepth;

  Catalog decode({
    Map<String, Object?>? manifest,
    Map<String, Object?>? paymentInstruments,
    Map<String, Object?>? pointPrograms,
    Map<String, Object?>? rewardRules,
    Map<String, Object?>? sources,
  }) {
    try {
      return Catalog(
        catalogVersion: _text(manifest?['catalogVersion']),
        generatedAt: _text(manifest?['generatedAt']),
        paymentInstruments: _decodeItems(
          paymentInstruments,
          _decodeInstrument,
        ),
        pointPrograms: _decodeItems(pointPrograms, _decodePointProgram),
        rewardRules: _decodeItems(rewardRules, _decodeRewardRule),
        sources: _decodeItems(sources, _decodeSource),
      );
    } catch (_) {
      return Catalog.empty();
    }
  }

  List<T> _decodeItems<T>(
    Map<String, Object?>? document,
    T? Function(Map<String, Object?> item) decoder,
  ) {
    final items = document?['items'];
    if (items is! List) {
      return const <Never>[];
    }

    final result = <T>[];
    final seenIds = <String>{};

    for (final raw in items) {
      final item = _objectMap(raw);
      if (item == null) {
        continue;
      }

      final id = _text(item['id']);
      if (id != null && !seenIds.add(id)) {
        continue;
      }

      try {
        final decoded = decoder(item);
        if (decoded != null) {
          result.add(decoded);
        }
      } catch (_) {
        // A single malformed record must not fail the whole catalog.
      }
    }

    return List<T>.unmodifiable(result);
  }

  PaymentInstrument? _decodeInstrument(Map<String, Object?> item) {
    final id = _id(item['id']);
    final name = _text(item['name']);
    final shortName = _text(item['shortName']);
    final instrumentType = _text(item['instrumentType']);
    final issuerName = _text(item['issuerName']);
    final status = _status(item['status']);
    final lastVerifiedAt = _date(item['lastVerifiedAt']);

    if (id == null ||
        name == null ||
        shortName == null ||
        instrumentType == null ||
        issuerName == null ||
        status == null ||
        lastVerifiedAt == null) {
      return null;
    }

    return PaymentInstrument(
      id: id,
      name: name,
      shortName: shortName,
      instrumentType: instrumentType,
      issuerName: issuerName,
      partnerInstitutionName: _text(item['partnerInstitutionName']),
      availableBrandIds: _ids(item['availableBrandIds']),
      annualFee: MoneyYen(_int(item['annualFee']) ?? 0),
      supportedModeIds: _ids(item['supportedModeIds']),
      supportedRouteIds: _ids(item['supportedRouteIds']),
      validityPeriod: _validity(item),
      status: status,
      sourceIds: _ids(item['sourceIds']),
      lastVerifiedAt: lastVerifiedAt,
      displayClaims: _texts(item['displayClaims']),
      tags: _ids(item['tags']),
      notes: _texts(item['notes']),
    );
  }

  PointProgram? _decodePointProgram(Map<String, Object?> item) {
    final id = _id(item['id']);
    final name = _text(item['name']);
    final issuerName = _text(item['issuerName']);
    final unitName = _text(item['unitName']);
    final status = _status(item['status']);
    final lastVerifiedAt = _date(item['lastVerifiedAt']);

    if (id == null ||
        name == null ||
        issuerName == null ||
        unitName == null ||
        status == null ||
        lastVerifiedAt == null) {
      return null;
    }

    final valueDefinition = _pointValueDefinition(
      _objectMap(item['valueDefinition']),
    );
    final expiration = _pointExpiration(_objectMap(item['expiration']));

    if (valueDefinition == null || expiration == null) {
      return null;
    }

    return PointProgram(
      id: id,
      name: name,
      issuerName: issuerName,
      unitName: unitName,
      valueDefinition: valueDefinition,
      expiration: expiration,
      status: status,
      sourceIds: _ids(item['sourceIds']),
      lastVerifiedAt: lastVerifiedAt,
      notes: _texts(item['notes']),
    );
  }

  CatalogSource? _decodeSource(Map<String, Object?> item) {
    final id = _id(item['id']);
    final title = _text(item['title']);
    final urlText = _text(item['url']);
    final publisher = _text(item['publisher']);
    final sourceType = _sourceType(item['sourceType']);
    final accessStatus = _accessStatus(item['accessStatus']);
    final reliability = _reliability(item['reliability']);
    final lastVerifiedAt = _date(item['lastVerifiedAt']);

    final url = urlText == null ? null : Uri.tryParse(urlText);

    if (id == null ||
        title == null ||
        url == null ||
        publisher == null ||
        sourceType == null ||
        accessStatus == null ||
        reliability == null ||
        lastVerifiedAt == null) {
      return null;
    }

    return CatalogSource(
      id: id,
      title: title,
      url: url,
      publisher: publisher,
      sourceType: sourceType,
      publishedAt: _date(item['publishedAt']),
      lastVerifiedAt: lastVerifiedAt,
      accessStatus: accessStatus,
      reliability: reliability,
      relevantSections: _texts(item['relevantSections']),
      summary: _text(item['summary']) ?? '',
      contentHash: _text(item['contentHash']),
      notes: _texts(item['notes']),
    );
  }

  RewardRule? _decodeRewardRule(Map<String, Object?> item) {
    final id = _id(item['id']);
    final name = _text(item['name']);
    final ruleKind = _ruleKind(item['ruleKind']);
    final status = _status(item['status']);
    final dateBasis = _dateBasis(item['dateBasis']);
    final timezone = _text(item['timezone']);
    final lastVerifiedAt = _date(item['lastVerifiedAt']);

    if (id == null ||
        name == null ||
        ruleKind == null ||
        status == null ||
        dateBasis == null ||
        timezone == null ||
        lastVerifiedAt == null) {
      return null;
    }

    final calculation = _calculation(_objectMap(item['calculation']));
    final aggregation = _aggregation(_objectMap(item['aggregation']));
    final stacking = _stacking(_objectMap(item['stacking']));
    final selectors = _selectorSet(_objectMap(item['selectors']));
    final exclusions = _selectorSet(_objectMap(item['exclusions']));

    if (calculation == null ||
        aggregation == null ||
        stacking == null ||
        selectors == null ||
        exclusions == null) {
      return null;
    }

    final rawCondition = item['conditionExpression'];
    ConditionExpression? conditionExpression;
    if (rawCondition != null) {
      conditionExpression = _condition(_objectMap(rawCondition), 1);
      if (conditionExpression == null) {
        return null;
      }
    }

    return RewardRule(
      id: id,
      name: name,
      description: _text(item['description']) ?? '',
      ruleKind: ruleKind,
      selectors: selectors,
      exclusions: exclusions,
      conditionExpression: conditionExpression,
      calculation: calculation,
      outputPointProgramId: _id(item['outputPointProgramId']),
      aggregation: aggregation,
      stacking: stacking,
      cap: _cap(_objectMap(item['cap'])),
      validityPeriod: _validity(item),
      dateBasis: dateBasis,
      timezone: timezone,
      displayClaim: _text(item['displayClaim']),
      sourceIds: _ids(item['sourceIds']),
      lastVerifiedAt: lastVerifiedAt,
      status: status,
      priority: _int(item['priority']) ?? 0,
      tags: _ids(item['tags']),
      notes: _texts(item['notes']),
    );
  }

  PointValueDefinition? _pointValueDefinition(
    Map<String, Object?>? definition,
  ) {
    if (definition == null) {
      return null;
    }

    switch (_text(definition['valueType'])) {
      case 'fixed':
        final rate = _rational(_objectMap(definition['yenPerPoint']));
        return rate == null ? null : FixedPointValueDefinition(rate);
      case 'variable':
        return const VariablePointValueDefinition();
      case 'unset':
        return const UnsetPointValueDefinition();
      default:
        return null;
    }
  }

  PointExpiration? _pointExpiration(Map<String, Object?>? value) {
    if (value == null) {
      return null;
    }

    switch (_text(value['expirationType'])) {
      case 'none':
        return const NoPointExpiration();
      case 'fixedDate':
        final expiresOn = _date(value['expiresOn']);
        return expiresOn == null
            ? null
            : FixedDatePointExpiration(expiresOn);
      case 'durationMonths':
        final months = _int(value['months']);
        return months == null ? null : DurationMonthsPointExpiration(months);
      case 'unknown':
        return const UnknownPointExpiration();
      default:
        return null;
    }
  }

  RewardCalculation? _calculation(Map<String, Object?>? value) {
    if (value == null) {
      return null;
    }

    switch (_text(value['calculationType'])) {
      case 'unitPoints':
        final amountUnit = _int(value['amountUnitYen']);
        final pointsPerUnit = _int(value['pointsPerUnit']);
        final rounding = _rounding(value['rounding']);

        if (amountUnit == null ||
            pointsPerUnit == null ||
            rounding == null ||
            amountUnit < 1) {
          return null;
        }

        return UnitPointsRewardCalculation(
          amountUnit: MoneyYen(amountUnit),
          pointsPerUnit: PointAmount(pointsPerUnit),
          rounding: rounding,
        );
      case 'rateFraction':
        final numerator = _int(value['numerator']);
        final denominator = _int(value['denominator']);
        final rounding = _rounding(value['rounding']);

        if (numerator == null || denominator == null || rounding == null) {
          return null;
        }

        final rate = _rational(<String, Object?>{
          'numerator': numerator,
          'denominator': denominator,
        });

        return rate == null
            ? null
            : RateFractionRewardCalculation(rate: rate, rounding: rounding);
      case 'fixedPoints':
        final points = _int(value['points']);
        return points == null ? null : FixedPointsRewardCalculation(
              PointAmount(points),
            );
      case 'mirror':
        final sourceRuleId = _id(value['sourceRuleId']);
        final multiplierNumerator = _int(value['multiplierNumerator']);
        final multiplierDenominator = _int(value['multiplierDenominator']);
        final inheritEligibility = _bool(value['inheritEligibility']);
        final inheritExclusions = _bool(value['inheritExclusions']);
        final useFinalSourceAmount = _bool(value['useFinalSourceAmount']);

        if (sourceRuleId == null ||
            multiplierNumerator == null ||
            multiplierDenominator == null ||
            inheritEligibility == null ||
            inheritExclusions == null ||
            useFinalSourceAmount == null) {
          return null;
        }

        final multiplier = _rational(<String, Object?>{
          'numerator': multiplierNumerator,
          'denominator': multiplierDenominator,
        });

        return multiplier == null
            ? null
            : MirrorRewardCalculation(
                sourceRuleId: sourceRuleId,
                multiplier: multiplier,
                inheritEligibility: inheritEligibility,
                inheritExclusions: inheritExclusions,
                useFinalSourceAmount: useFinalSourceAmount,
              );
      case 'thresholdBonus':
        final threshold = _int(value['thresholdAmountYen']);
        final bonus = _int(value['bonusPoints']);
        final maxAwards = _int(value['maxAwardsPerPeriod']);

        if (threshold == null || bonus == null || maxAwards == null) {
          return null;
        }

        return ThresholdBonusRewardCalculation(
          thresholdAmount: MoneyYen(threshold),
          bonusPoints: PointAmount(bonus),
          maxAwardsPerPeriod: maxAwards,
        );
      case 'tiered':
        final rawTiers = value['tiers'];
        if (rawTiers is! List || rawTiers.isEmpty) {
          return null;
        }

        final tiers = <RewardTier>[];
        for (final rawTier in rawTiers) {
          final tier = _objectMap(rawTier);
          if (tier == null) {
            return null;
          }

          final minimum = _int(tier['minimumAmountYen']);
          final maximum = tier['maximumAmountYenExclusive'];
          final tierCalculation = _calculation(
            _objectMap(tier['calculation']),
          );

          if (minimum == null || tierCalculation == null) {
            return null;
          }

          MoneyYen? maximumExclusive;
          if (maximum != null) {
            if (maximum is! int) {
              return null;
            }
            maximumExclusive = MoneyYen(maximum);
          }

          tiers.add(
            RewardTier(
              minimumAmount: MoneyYen(minimum),
              maximumAmountExclusive: maximumExclusive,
              calculation: tierCalculation,
            ),
          );
        }

        return TieredRewardCalculation(tiers);
      case 'none':
        return const NoRewardCalculation();
      default:
        return null;
    }
  }

  RewardAggregation? _aggregation(Map<String, Object?>? value) {
    if (value == null) {
      return null;
    }

    final scope = _aggregationScope(value['scope']);
    final timing = _text(value['conditionEvaluationTiming']);
    final incrementalAward = _bool(value['incrementalAward']);
    final minimum = _int(value['periodMinimumEligibleSpendYen']);

    if (scope == null ||
        timing == null ||
        incrementalAward == null ||
        minimum == null) {
      return null;
    }

    return RewardAggregation(
      scope: scope,
      aggregationKey: _id(value['aggregationKey']),
      periodMinimumEligibleSpend: MoneyYen(minimum),
      conditionEvaluationTiming: timing,
      incrementalAward: incrementalAward,
    );
  }

  RewardStacking? _stacking(Map<String, Object?>? value) {
    if (value == null) {
      return null;
    }

    final policy = _text(value['policy']);
    final applicationOrder = _int(value['applicationOrder']);

    if (policy == null || applicationOrder == null) {
      return null;
    }

    return RewardStacking(
      policy: policy,
      exclusiveGroupId: _id(value['exclusiveGroupId']),
      replacesRuleIds: _ids(value['replacesRuleIds']),
      suppressesRuleIds: _ids(value['suppressesRuleIds']),
      suppressesTags: _ids(value['suppressesTags']),
      dependsOnRuleIds: _ids(value['dependsOnRuleIds']),
      applicationOrder: applicationOrder,
    );
  }

  RewardCap? _cap(Map<String, Object?>? value) {
    if (value == null) {
      return null;
    }

    final capType = _text(value['capType']);
    final limit = _int(value['limit']);
    final periodType = _text(value['periodType']);
    final appliesTo = _text(value['appliesTo']);
    final overflowPolicy = _text(value['overflowPolicy']);

    if (capType == null ||
        limit == null ||
        periodType == null ||
        appliesTo == null ||
        overflowPolicy == null) {
      return null;
    }

    return RewardCap(
      capType: capType,
      limit: limit,
      periodType: periodType,
      scopeKey: _id(value['scopeKey']),
      appliesTo: appliesTo,
      overflowPolicy: overflowPolicy,
    );
  }

  SelectorSet? _selectorSet(Map<String, Object?>? value) {
    if (value == null) {
      return null;
    }

    return SelectorSet(
      instrumentIds: _ids(value['instrumentIds']),
      modeIds: _ids(value['modeIds']),
      routeIds: _ids(value['routeIds']),
      fundingRelationIds: _ids(value['fundingRelationIds']),
      merchantIds: _ids(value['merchantIds']),
      merchantGroupIds: _ids(value['merchantGroupIds']),
      categoryIds: _ids(value['categoryIds']),
      brandIds: _ids(value['brandIds']),
      locationIds: _ids(value['locationIds']),
      transactionTags: _ids(value['transactionTags']),
    );
  }

  ConditionExpression? _condition(Map<String, Object?>? node, int depth) {
    if (node == null || depth > maximumConditionDepth) {
      return null;
    }

    switch (_text(node['nodeType'])) {
      case 'all':
        final children = _conditionChildren(node['children'], depth + 1);
        return children == null ? null : AllConditionExpression(children);
      case 'any':
        final children = _conditionChildren(node['children'], depth + 1);
        return children == null ? null : AnyConditionExpression(children);
      case 'not':
        final child = _condition(_objectMap(node['child']), depth + 1);
        return child == null ? null : NotConditionExpression(child);
      case 'condition':
        final conditionId = _id(node['conditionId']);
        return conditionId == null
            ? null
            : ConditionReferenceExpression(conditionId);
      case 'comparison':
        final conditionId = _id(node['conditionId']);
        final operator = _comparisonOperator(node['comparisonOperator']);
        final value = _comparisonValue(node['value']);

        if (conditionId == null || operator == null || value == null) {
          return null;
        }

        return ComparisonConditionExpression(
          conditionId: conditionId,
          operator: operator,
          value: value,
        );
      default:
        return null;
    }
  }

  List<ConditionExpression>? _conditionChildren(Object? value, int depth) {
    if (value is! List || value.isEmpty) {
      return null;
    }

    final result = <ConditionExpression>[];
    for (final raw in value) {
      final child = _condition(_objectMap(raw), depth);
      if (child == null) {
        return null;
      }
      result.add(child);
    }

    return result;
  }

  ConditionComparisonValue? _comparisonValue(Object? value) {
    if (value is String) {
      return StringConditionComparisonValue(value);
    }
    if (value is int) {
      return IntegerConditionComparisonValue(value);
    }
    if (value is bool) {
      return BooleanConditionComparisonValue(value);
    }
    if (value == null) {
      return const NullConditionComparisonValue();
    }
    if (value is Map) {
      final rational = _rational(_objectMap(value));
      return rational == null ? null : RationalConditionComparisonValue(rational);
    }
    if (value is List) {
      final values = <Object>[];
      for (final entry in value) {
        if (entry is! String && entry is! int && entry is! bool) {
          return null;
        }
        values.add(entry);
      }
      return ListConditionComparisonValue(values);
    }

    return null;
  }

  Map<String, Object?>? _objectMap(Object? value) {
    if (value is! Map) {
      return null;
    }

    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        return null;
      }
      result[key] = entry.value;
    }

    return result;
  }

  StableId? _id(Object? value) {
    if (value is! String) {
      return null;
    }

    return StableId.create(value).fold(
      onSuccess: (id) => id,
      onFailure: (_) => null,
    );
  }

  List<StableId> _ids(Object? value) {
    if (value is! List) {
      return const <StableId>[];
    }

    final result = <StableId>[];
    for (final entry in value) {
      final id = _id(entry);
      if (id != null && !result.contains(id)) {
        result.add(id);
      }
    }

    return result;
  }

  Rational? _rational(Map<String, Object?>? value) {
    if (value == null) {
      return null;
    }

    final numerator = _int(value['numerator']);
    final denominator = _int(value['denominator']);

    if (numerator == null || denominator == null) {
      return null;
    }

    return Rational.create(numerator, denominator).fold(
      onSuccess: (rational) => rational,
      onFailure: (_) => null,
    );
  }

  CalculationDate? _date(Object? value) {
    if (value is! String) {
      return null;
    }

    return CalculationDate.parse(value).fold(
      onSuccess: (date) => date,
      onFailure: (_) => null,
    );
  }

  ValidityPeriod _validity(Map<String, Object?> item) {
    final startsOn = _date(item['validFrom']);
    if (startsOn == null) {
      throw const FormatException('validFrom is required.');
    }

    return ValidityPeriod.create(
      startsOn: startsOn,
      endsBefore: _date(item['validUntilExclusive']),
    ).fold(
      onSuccess: (period) => period,
      onFailure: (_) => throw const FormatException('Invalid validity period.'),
    );
  }

  String? _text(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  int? _int(Object? value) => value is int ? value : null;

  bool? _bool(Object? value) => value is bool ? value : null;

  List<String> _texts(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return <String>[
      for (final entry in value)
        if (entry is String && entry.isNotEmpty) entry,
    ];
  }

  CatalogItemStatus? _status(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final status in CatalogItemStatus.values) {
      if (status.value == value) {
        return status;
      }
    }

    return null;
  }

  RewardRuleKind? _ruleKind(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final kind in RewardRuleKind.values) {
      if (kind.value == value) {
        return kind;
      }
    }

    return null;
  }

  RewardAggregationScope? _aggregationScope(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final scope in RewardAggregationScope.values) {
      if (scope.value == value) {
        return scope;
      }
    }

    return null;
  }

  RewardDateBasis? _dateBasis(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final basis in RewardDateBasis.values) {
      if (basis.value == value) {
        return basis;
      }
    }

    return null;
  }

  CatalogSourceType? _sourceType(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final type in CatalogSourceType.values) {
      if (type.value == value) {
        return type;
      }
    }

    return null;
  }

  CatalogSourceAccessStatus? _accessStatus(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final status in CatalogSourceAccessStatus.values) {
      if (status.value == value) {
        return status;
      }
    }

    return null;
  }

  CatalogSourceReliability? _reliability(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final reliability in CatalogSourceReliability.values) {
      if (reliability.value == value) {
        return reliability;
      }
    }

    return null;
  }

  ComparisonOperator? _comparisonOperator(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final operator in ComparisonOperator.values) {
      if (operator.value == value) {
        return operator;
      }
    }

    return null;
  }

  RoundingMode? _rounding(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final mode in RoundingMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }

    return null;
  }
}

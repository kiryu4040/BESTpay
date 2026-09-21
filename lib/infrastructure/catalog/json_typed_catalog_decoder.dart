import '../../application/catalog/typed_catalog_decoder.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/app_error_code.dart';
import '../../core/result/app_result.dart';
import '../../core/value_objects/calculation_date.dart';
import '../../core/value_objects/money_yen.dart';
import '../../core/value_objects/point_amount.dart';
import '../../core/value_objects/rational.dart';
import '../../core/value_objects/rounding_mode.dart';
import '../../core/value_objects/stable_id.dart';
import '../../core/value_objects/tri_state.dart';
import '../../core/value_objects/validity_period.dart';
import '../../domain/catalog/catalog_snapshot.dart';
import '../../domain/catalog/models/catalog_types.dart';
import '../../domain/catalog/models/condition_models.dart';
import '../../domain/catalog/models/instrument_models.dart';
import '../../domain/catalog/models/merchant_models.dart';
import '../../domain/catalog/models/point_program_models.dart';
import '../../domain/catalog/models/reward_rule_models.dart';
import '../../domain/catalog/models/source_migration_models.dart';
import '../../domain/catalog/models/typed_catalog.dart';

/// Converts a schema-validated [CatalogSnapshot] to immutable domain models.
final class JsonTypedCatalogDecoder implements TypedCatalogDecoder {
  const JsonTypedCatalogDecoder();

  @override
  AppResult<TypedCatalog> decode(CatalogSnapshot snapshot) {
    try {
      return AppSuccess<TypedCatalog>(
        TypedCatalog(
          paymentInstruments: _decodeItems(
            snapshot,
            'payment_instruments.json',
            _decodePaymentInstrument,
          ),
          paymentRoutes: _decodeItems(
            snapshot,
            'payment_routes.json',
            _decodePaymentRoute,
          ),
          paymentModes: _decodeItems(
            snapshot,
            'payment_modes.json',
            _decodePaymentMode,
          ),
          fundingRelations: _decodeItems(
            snapshot,
            'funding_relations.json',
            _decodeFundingRelation,
          ),
          merchantGroups: _decodeItems(
            snapshot,
            'merchant_groups.json',
            _decodeMerchantGroup,
          ),
          merchants: _decodeItems(
            snapshot,
            'merchants.json',
            _decodeMerchant,
          ),
          merchantCategories: _decodeItems(
            snapshot,
            'merchant_categories.json',
            _decodeMerchantCategory,
          ),
          pointPrograms: _decodeItems(
            snapshot,
            'point_programs.json',
            _decodePointProgram,
          ),
          conditionDefinitions: _decodeItems(
            snapshot,
            'condition_definitions.json',
            _decodeConditionDefinition,
          ),
          rewardRules: _decodeItems(
            snapshot,
            'reward_rules.json',
            _decodeRewardRule,
          ),
          sources: _decodeItems(
            snapshot,
            'sources.json',
            _decodeSource,
          ),
          idMigrations: _decodeItems(
            snapshot,
            'id_migrations.json',
            _decodeIdMigration,
          ),
        ),
      );
    } catch (error) {
      return AppFailure<TypedCatalog>(
        AppError(
          code: AppErrorCode.catalogDecodeFailed,
          operation: 'typedCatalog.decode',
          context: <String, Object?>{
            'catalogVersion': snapshot.catalogVersion.value,
          },
          causeType: error.runtimeType.toString(),
        ),
      );
    }
  }
}

typedef _ItemDecoder<T> = T Function(
  Map<String, Object?> item,
  String path,
);

List<T> _decodeItems<T>(
  CatalogSnapshot snapshot,
  String fileName,
  _ItemDecoder<T> decoder,
) {
  final document = _objectMap(
    snapshot.documents[fileName],
    fileName,
  );
  final values = _objectList(
    document['items'],
    '$fileName/items',
  );
  final result = <T>[];

  for (var index = 0; index < values.length; index++) {
    final path = '$fileName/items/$index';
    result.add(decoder(_objectMap(values[index], path), path));
  }

  return List<T>.unmodifiable(result);
}

PaymentInstrument _decodePaymentInstrument(
  Map<String, Object?> item,
  String path,
) {
  return PaymentInstrument(
    id: _stableId(item['id'], '$path/id'),
    name: _string(item['name'], '$path/name'),
    shortName: _string(item['shortName'], '$path/shortName'),
    instrumentType: _string(
      item['instrumentType'],
      '$path/instrumentType',
    ),
    issuerName: _string(item['issuerName'], '$path/issuerName'),
    partnerInstitutionName: _nullableString(
      item['partnerInstitutionName'],
      '$path/partnerInstitutionName',
    ),
    availableBrandIds: _stableIds(
      item['availableBrandIds'],
      '$path/availableBrandIds',
    ),
    annualFee: MoneyYen(_integer(item['annualFee'], '$path/annualFee')),
    supportedModeIds: _stableIds(
      item['supportedModeIds'],
      '$path/supportedModeIds',
    ),
    supportedRouteIds: _stableIds(
      item['supportedRouteIds'],
      '$path/supportedRouteIds',
    ),
    validityPeriod: _validityPeriod(item, path),
    status: _catalogStatus(item['status'], '$path/status'),
    sourceIds: _stableIds(item['sourceIds'], '$path/sourceIds'),
    lastVerifiedAt: _date(
      item['lastVerifiedAt'],
      '$path/lastVerifiedAt',
    ),
    displayClaims: _strings(
      item['displayClaims'],
      '$path/displayClaims',
    ),
    tags: _stableIds(item['tags'], '$path/tags'),
    notes: _strings(item['notes'], '$path/notes'),
  );
}

PaymentRoute _decodePaymentRoute(
  Map<String, Object?> item,
  String path,
) {
  return PaymentRoute(
    id: _stableId(item['id'], '$path/id'),
    name: _string(item['name'], '$path/name'),
    routeType: _string(item['routeType'], '$path/routeType'),
    brandIds: _stableIds(item['brandIds'], '$path/brandIds'),
    deviceRequirement: _nullableString(
      item['deviceRequirement'],
      '$path/deviceRequirement',
    ),
    supportedInstrumentIds: _stableIds(
      item['supportedInstrumentIds'],
      '$path/supportedInstrumentIds',
    ),
    validityPeriod: _validityPeriod(item, path),
    status: _catalogStatus(item['status'], '$path/status'),
    sourceIds: _stableIds(item['sourceIds'], '$path/sourceIds'),
    notes: _strings(item['notes'], '$path/notes'),
  );
}

PaymentMode _decodePaymentMode(
  Map<String, Object?> item,
  String path,
) {
  return PaymentMode(
    id: _stableId(item['id'], '$path/id'),
    instrumentId: _stableId(
      item['instrumentId'],
      '$path/instrumentId',
    ),
    name: _string(item['name'], '$path/name'),
    modeType: _enumValue(
      PaymentModeType.values,
      item['modeType'],
      '$path/modeType',
      (value) => value.value,
    ),
    supportedRouteIds: _stableIds(
      item['supportedRouteIds'],
      '$path/supportedRouteIds',
    ),
    validityPeriod: _validityPeriod(item, path),
    status: _catalogStatus(item['status'], '$path/status'),
    sourceIds: _stableIds(item['sourceIds'], '$path/sourceIds'),
    notes: _strings(item['notes'], '$path/notes'),
  );
}

FundingRelation _decodeFundingRelation(
  Map<String, Object?> item,
  String path,
) {
  return FundingRelation(
    id: _stableId(item['id'], '$path/id'),
    sourceInstrumentId: _stableId(
      item['sourceInstrumentId'],
      '$path/sourceInstrumentId',
    ),
    destinationInstrumentId: _stableId(
      item['destinationInstrumentId'],
      '$path/destinationInstrumentId',
    ),
    relationType: _string(
      item['relationType'],
      '$path/relationType',
    ),
    validityPeriod: _validityPeriod(item, path),
    status: _catalogStatus(item['status'], '$path/status'),
    sourceIds: _stableIds(item['sourceIds'], '$path/sourceIds'),
    notes: _strings(item['notes'], '$path/notes'),
  );
}

Merchant _decodeMerchant(
  Map<String, Object?> item,
  String path,
) {
  return Merchant(
    id: _stableId(item['id'], '$path/id'),
    name: _string(item['name'], '$path/name'),
    merchantGroupIds: _stableIds(
      item['merchantGroupIds'],
      '$path/merchantGroupIds',
    ),
    categoryIds: _stableIds(
      item['categoryIds'],
      '$path/categoryIds',
    ),
    locationIds: _stableIds(
      item['locationIds'],
      '$path/locationIds',
    ),
    status: _catalogStatus(item['status'], '$path/status'),
    sourceIds: _stableIds(item['sourceIds'], '$path/sourceIds'),
    notes: _strings(item['notes'], '$path/notes'),
  );
}

MerchantGroup _decodeMerchantGroup(
  Map<String, Object?> item,
  String path,
) {
  return MerchantGroup(
    id: _stableId(item['id'], '$path/id'),
    name: _string(item['name'], '$path/name'),
    description: _string(item['description'], '$path/description'),
    status: _catalogStatus(item['status'], '$path/status'),
    sourceIds: _stableIds(item['sourceIds'], '$path/sourceIds'),
    notes: _strings(item['notes'], '$path/notes'),
  );
}

MerchantCategory _decodeMerchantCategory(
  Map<String, Object?> item,
  String path,
) {
  return MerchantCategory(
    id: _stableId(item['id'], '$path/id'),
    name: _string(item['name'], '$path/name'),
    parentCategoryId: _nullableStableId(
      item['parentCategoryId'],
      '$path/parentCategoryId',
    ),
    status: _catalogStatus(item['status'], '$path/status'),
    sourceIds: _stableIds(item['sourceIds'], '$path/sourceIds'),
    notes: _strings(item['notes'], '$path/notes'),
  );
}

PointProgram _decodePointProgram(
  Map<String, Object?> item,
  String path,
) {
  return PointProgram(
    id: _stableId(item['id'], '$path/id'),
    name: _string(item['name'], '$path/name'),
    issuerName: _string(item['issuerName'], '$path/issuerName'),
    unitName: _string(item['unitName'], '$path/unitName'),
    valueDefinition: _pointValueDefinition(
      item['valueDefinition'],
      '$path/valueDefinition',
    ),
    expiration: _pointExpiration(
      item['expiration'],
      '$path/expiration',
    ),
    status: _catalogStatus(item['status'], '$path/status'),
    sourceIds: _stableIds(item['sourceIds'], '$path/sourceIds'),
    lastVerifiedAt: _date(
      item['lastVerifiedAt'],
      '$path/lastVerifiedAt',
    ),
    notes: _strings(item['notes'], '$path/notes'),
  );
}

PointValueDefinition _pointValueDefinition(
  Object? value,
  String path,
) {
  final source = _objectMap(value, path);
  final type = _string(source['valueType'], '$path/valueType');

  return switch (type) {
    'fixed' => FixedPointValueDefinition(
        _rational(source['yenPerPoint'], '$path/yenPerPoint'),
      ),
    'variable' => const VariablePointValueDefinition(),
    'unset' => const UnsetPointValueDefinition(),
    _ => throw FormatException('Unknown point value type at $path.'),
  };
}

PointExpiration _pointExpiration(
  Object? value,
  String path,
) {
  final source = _objectMap(value, path);
  final type = _string(
    source['expirationType'],
    '$path/expirationType',
  );

  return switch (type) {
    'none' => const NoPointExpiration(),
    'fixedDate' => FixedDatePointExpiration(
        _date(source['expiresOn'], '$path/expiresOn'),
      ),
    'durationMonths' => DurationMonthsPointExpiration(
        _integer(source['months'], '$path/months'),
      ),
    'unknown' => const UnknownPointExpiration(),
    _ => throw FormatException('Unknown point expiration type at $path.'),
  };
}

ConditionDefinition _decodeConditionDefinition(
  Map<String, Object?> item,
  String path,
) {
  return ConditionDefinition(
    id: _stableId(item['id'], '$path/id'),
    name: _string(item['name'], '$path/name'),
    description: _string(item['description'], '$path/description'),
    valueType: _string(item['valueType'], '$path/valueType'),
    defaultState: _enumValue(
      TriState.values,
      item['defaultState'],
      '$path/defaultState',
      (value) => value.name,
    ),
    verificationMethod: _enumValue(
      ConditionVerificationMethod.values,
      item['verificationMethod'],
      '$path/verificationMethod',
      (value) => value.value,
    ),
    scope: _string(item['scope'], '$path/scope'),
    sensitivity: _string(item['sensitivity'], '$path/sensitivity'),
    validityPeriod: _validityPeriod(item, path),
    status: _catalogStatus(item['status'], '$path/status'),
    sourceIds: _stableIds(item['sourceIds'], '$path/sourceIds'),
    notes: _strings(item['notes'], '$path/notes'),
  );
}

RewardRule _decodeRewardRule(
  Map<String, Object?> item,
  String path,
) {
  final conditionValue = item['conditionExpression'];
  final capValue = item['cap'];

  return RewardRule(
    id: _stableId(item['id'], '$path/id'),
    name: _string(item['name'], '$path/name'),
    description: _string(item['description'], '$path/description'),
    ruleKind: _enumValue(
      RewardRuleKind.values,
      item['ruleKind'],
      '$path/ruleKind',
      (value) => value.value,
    ),
    selectors: _selectorSet(item['selectors'], '$path/selectors'),
    exclusions: _selectorSet(item['exclusions'], '$path/exclusions'),
    conditionExpression: conditionValue == null
        ? null
        : _conditionExpression(
            conditionValue,
            '$path/conditionExpression',
            _ConditionBudget(),
            1,
          ),
    calculation: _rewardCalculation(
      item['calculation'],
      '$path/calculation',
    ),
    outputPointProgramId: _nullableStableId(
      item['outputPointProgramId'],
      '$path/outputPointProgramId',
    ),
    aggregation: _rewardAggregation(
      item['aggregation'],
      '$path/aggregation',
    ),
    stacking: _rewardStacking(item['stacking'], '$path/stacking'),
    cap: capValue == null ? null : _rewardCap(capValue, '$path/cap'),
    validityPeriod: _validityPeriod(item, path),
    dateBasis: _enumValue(
      RewardDateBasis.values,
      item['dateBasis'],
      '$path/dateBasis',
      (value) => value.value,
    ),
    timezone: _string(item['timezone'], '$path/timezone'),
    displayClaim: _nullableString(
      item['displayClaim'],
      '$path/displayClaim',
    ),
    sourceIds: _stableIds(item['sourceIds'], '$path/sourceIds'),
    lastVerifiedAt: _date(
      item['lastVerifiedAt'],
      '$path/lastVerifiedAt',
    ),
    status: _catalogStatus(item['status'], '$path/status'),
    priority: _integer(item['priority'], '$path/priority'),
    tags: _stableIds(item['tags'], '$path/tags'),
    notes: _strings(item['notes'], '$path/notes'),
  );
}

SelectorSet _selectorSet(Object? value, String path) {
  final source = _objectMap(value, path);

  return SelectorSet(
    instrumentIds: _stableIds(
      source['instrumentIds'],
      '$path/instrumentIds',
    ),
    modeIds: _stableIds(source['modeIds'], '$path/modeIds'),
    routeIds: _stableIds(source['routeIds'], '$path/routeIds'),
    fundingRelationIds: _stableIds(
      source['fundingRelationIds'],
      '$path/fundingRelationIds',
    ),
    merchantIds: _stableIds(
      source['merchantIds'],
      '$path/merchantIds',
    ),
    merchantGroupIds: _stableIds(
      source['merchantGroupIds'],
      '$path/merchantGroupIds',
    ),
    categoryIds: _stableIds(
      source['categoryIds'],
      '$path/categoryIds',
    ),
    brandIds: _stableIds(source['brandIds'], '$path/brandIds'),
    locationIds: _stableIds(
      source['locationIds'],
      '$path/locationIds',
    ),
    transactionTags: _stableIds(
      source['transactionTags'],
      '$path/transactionTags',
    ),
  );
}

ConditionExpression _conditionExpression(
  Object? value,
  String path,
  _ConditionBudget budget,
  int depth,
) {
  if (depth > 10) {
    throw FormatException('ConditionExpression depth exceeds 10 at $path.');
  }

  budget.nodeCount++;
  if (budget.nodeCount > 100) {
    throw const FormatException(
      'ConditionExpression node count exceeds 100.',
    );
  }

  final source = _objectMap(value, path);
  final type = _string(source['nodeType'], '$path/nodeType');

  switch (type) {
    case 'all':
      final children = _objectList(source['children'], '$path/children');
      return AllConditionExpression(
        <ConditionExpression>[
          for (var index = 0; index < children.length; index++)
            _conditionExpression(
              children[index],
              '$path/children/$index',
              budget,
              depth + 1,
            ),
        ],
      );
    case 'any':
      final children = _objectList(source['children'], '$path/children');
      return AnyConditionExpression(
        <ConditionExpression>[
          for (var index = 0; index < children.length; index++)
            _conditionExpression(
              children[index],
              '$path/children/$index',
              budget,
              depth + 1,
            ),
        ],
      );
    case 'not':
      return NotConditionExpression(
        _conditionExpression(
          source['child'],
          '$path/child',
          budget,
          depth + 1,
        ),
      );
    case 'condition':
      return ConditionReferenceExpression(
        _stableId(source['conditionId'], '$path/conditionId'),
      );
    case 'comparison':
      return ComparisonConditionExpression(
        conditionId: _stableId(
          source['conditionId'],
          '$path/conditionId',
        ),
        operator: _enumValue(
          ComparisonOperator.values,
          source['comparisonOperator'],
          '$path/comparisonOperator',
          (value) => value.value,
        ),
        value: _comparisonValue(source['value'], '$path/value'),
      );
    default:
      throw FormatException('Unknown condition node type at $path.');
  }
}

ConditionComparisonValue _comparisonValue(
  Object? value,
  String path,
) {
  if (value == null) {
    return const NullConditionComparisonValue();
  }
  if (value is String) {
    return StringConditionComparisonValue(value);
  }
  if (value is int) {
    return IntegerConditionComparisonValue(value);
  }
  if (value is bool) {
    return BooleanConditionComparisonValue(value);
  }
  if (value is Map) {
    return RationalConditionComparisonValue(_rational(value, path));
  }
  if (value is List) {
    final values = <Object>[];

    for (var index = 0; index < value.length; index++) {
      final item = value[index];
      if (item is! String && item is! int && item is! bool) {
        throw FormatException(
          'Unsupported comparison list value at $path/$index.',
        );
      }
      values.add(item as Object);
    }

    return ListConditionComparisonValue(values);
  }

  throw FormatException('Unsupported comparison value at $path.');
}

RewardCalculation _rewardCalculation(Object? value, String path) {
  final source = _objectMap(value, path);
  final type = _string(
    source['calculationType'],
    '$path/calculationType',
  );

  switch (type) {
    case 'unitPoints':
      return UnitPointsRewardCalculation(
        amountUnit: MoneyYen(
          _integer(source['amountUnitYen'], '$path/amountUnitYen'),
        ),
        pointsPerUnit: PointAmount(
          _integer(source['pointsPerUnit'], '$path/pointsPerUnit'),
        ),
        rounding: _roundingMode(source['rounding'], '$path/rounding'),
      );
    case 'rateFraction':
      return RateFractionRewardCalculation(
        rate: _rationalParts(
          source['numerator'],
          source['denominator'],
          path,
        ),
        rounding: _roundingMode(source['rounding'], '$path/rounding'),
      );
    case 'fixedPoints':
      return FixedPointsRewardCalculation(
        PointAmount(_integer(source['points'], '$path/points')),
      );
    case 'mirror':
      return MirrorRewardCalculation(
        sourceRuleId: _stableId(
          source['sourceRuleId'],
          '$path/sourceRuleId',
        ),
        multiplier: _rationalParts(
          source['multiplierNumerator'],
          source['multiplierDenominator'],
          '$path/multiplier',
        ),
        inheritEligibility: _boolean(
          source['inheritEligibility'],
          '$path/inheritEligibility',
        ),
        inheritExclusions: _boolean(
          source['inheritExclusions'],
          '$path/inheritExclusions',
        ),
        useFinalSourceAmount: _boolean(
          source['useFinalSourceAmount'],
          '$path/useFinalSourceAmount',
        ),
      );
    case 'thresholdBonus':
      return ThresholdBonusRewardCalculation(
        thresholdAmount: MoneyYen(
          _integer(
            source['thresholdAmountYen'],
            '$path/thresholdAmountYen',
          ),
        ),
        bonusPoints: PointAmount(
          _integer(source['bonusPoints'], '$path/bonusPoints'),
        ),
        maxAwardsPerPeriod: _integer(
          source['maxAwardsPerPeriod'],
          '$path/maxAwardsPerPeriod',
        ),
      );
    case 'tiered':
      final values = _objectList(source['tiers'], '$path/tiers');
      return TieredRewardCalculation(
        <RewardTier>[
          for (var index = 0; index < values.length; index++)
            _rewardTier(values[index], '$path/tiers/$index'),
        ],
      );
    case 'none':
      return const NoRewardCalculation();
    default:
      throw FormatException('Unknown reward calculation type at $path.');
  }
}

RewardTier _rewardTier(Object? value, String path) {
  final source = _objectMap(value, path);
  final maximum = source['maximumAmountYenExclusive'];

  return RewardTier(
    minimumAmount: MoneyYen(
      _integer(source['minimumAmountYen'], '$path/minimumAmountYen'),
    ),
    maximumAmountExclusive: maximum == null
        ? null
        : MoneyYen(
            _integer(maximum, '$path/maximumAmountYenExclusive'),
          ),
    calculation: _rewardCalculation(
      source['calculation'],
      '$path/calculation',
    ),
  );
}

RewardAggregation _rewardAggregation(Object? value, String path) {
  final source = _objectMap(value, path);

  return RewardAggregation(
    scope: _enumValue(
      RewardAggregationScope.values,
      source['scope'],
      '$path/scope',
      (value) => value.value,
    ),
    aggregationKey: _nullableStableId(
      source['aggregationKey'],
      '$path/aggregationKey',
    ),
    periodMinimumEligibleSpend: MoneyYen(
      _integer(
        source['periodMinimumEligibleSpendYen'],
        '$path/periodMinimumEligibleSpendYen',
      ),
    ),
    conditionEvaluationTiming: _string(
      source['conditionEvaluationTiming'],
      '$path/conditionEvaluationTiming',
    ),
    incrementalAward: _boolean(
      source['incrementalAward'],
      '$path/incrementalAward',
    ),
  );
}

RewardStacking _rewardStacking(Object? value, String path) {
  final source = _objectMap(value, path);

  return RewardStacking(
    policy: _string(source['policy'], '$path/policy'),
    exclusiveGroupId: _nullableStableId(
      source['exclusiveGroupId'],
      '$path/exclusiveGroupId',
    ),
    replacesRuleIds: _stableIds(
      source['replacesRuleIds'],
      '$path/replacesRuleIds',
    ),
    suppressesRuleIds: _stableIds(
      source['suppressesRuleIds'],
      '$path/suppressesRuleIds',
    ),
    suppressesTags: _stableIds(
      source['suppressesTags'],
      '$path/suppressesTags',
    ),
    dependsOnRuleIds: _stableIds(
      source['dependsOnRuleIds'],
      '$path/dependsOnRuleIds',
    ),
    applicationOrder: _integer(
      source['applicationOrder'],
      '$path/applicationOrder',
    ),
  );
}

RewardCap _rewardCap(Object? value, String path) {
  final source = _objectMap(value, path);

  return RewardCap(
    capType: _string(source['capType'], '$path/capType'),
    limit: _integer(source['limit'], '$path/limit'),
    periodType: _string(source['periodType'], '$path/periodType'),
    scopeKey: _nullableStableId(
      source['scopeKey'],
      '$path/scopeKey',
    ),
    appliesTo: _string(source['appliesTo'], '$path/appliesTo'),
    overflowPolicy: _string(
      source['overflowPolicy'],
      '$path/overflowPolicy',
    ),
  );
}

CatalogSource _decodeSource(
  Map<String, Object?> item,
  String path,
) {
  return CatalogSource(
    id: _stableId(item['id'], '$path/id'),
    title: _string(item['title'], '$path/title'),
    url: Uri.parse(_string(item['url'], '$path/url')),
    publisher: _string(item['publisher'], '$path/publisher'),
    sourceType: _enumValue(
      CatalogSourceType.values,
      item['sourceType'],
      '$path/sourceType',
      (value) => value.value,
    ),
    publishedAt: _nullableDate(
      item['publishedAt'],
      '$path/publishedAt',
    ),
    lastVerifiedAt: _date(
      item['lastVerifiedAt'],
      '$path/lastVerifiedAt',
    ),
    accessStatus: _enumValue(
      CatalogSourceAccessStatus.values,
      item['accessStatus'],
      '$path/accessStatus',
      (value) => value.value,
    ),
    reliability: _enumValue(
      CatalogSourceReliability.values,
      item['reliability'],
      '$path/reliability',
      (value) => value.value,
    ),
    relevantSections: _strings(
      item['relevantSections'],
      '$path/relevantSections',
    ),
    summary: _string(item['summary'], '$path/summary'),
    contentHash: _nullableString(
      item['contentHash'],
      '$path/contentHash',
    ),
    notes: _strings(item['notes'], '$path/notes'),
  );
}

IdMigration _decodeIdMigration(
  Map<String, Object?> item,
  String path,
) {
  return IdMigration(
    id: _stableId(item['id'], '$path/id'),
    entityType: _string(item['entityType'], '$path/entityType'),
    migrationType: _enumValue(
      IdMigrationType.values,
      item['migrationType'],
      '$path/migrationType',
      (value) => value.value,
    ),
    fromIds: _stableIds(item['fromIds'], '$path/fromIds'),
    toIds: _stableIds(item['toIds'], '$path/toIds'),
    evidenceSourceIds: _stableIds(
      item['evidenceSourceIds'],
      '$path/evidenceSourceIds',
    ),
    needsReview: _boolean(
      item['needsReview'],
      '$path/needsReview',
    ),
    effectiveFrom: _date(
      item['effectiveFrom'],
      '$path/effectiveFrom',
    ),
    notes: _strings(item['notes'], '$path/notes'),
  );
}

CatalogItemStatus _catalogStatus(Object? value, String path) {
  return _enumValue(
    CatalogItemStatus.values,
    value,
    path,
    (item) => item.value,
  );
}

RoundingMode _roundingMode(Object? value, String path) {
  return _enumValue(
    RoundingMode.values,
    value,
    path,
    (item) => item.name,
  );
}

ValidityPeriod _validityPeriod(
  Map<String, Object?> item,
  String path,
) {
  final result = ValidityPeriod.create(
    startsOn: _date(item['validFrom'], '$path/validFrom'),
    endsBefore: _nullableDate(
      item['validUntilExclusive'],
      '$path/validUntilExclusive',
    ),
  );

  return _successValue(result, '$path/validityPeriod');
}

Rational _rational(Object? value, String path) {
  final source = _objectMap(value, path);

  return _rationalParts(
    source['numerator'],
    source['denominator'],
    path,
  );
}

Rational _rationalParts(
  Object? numerator,
  Object? denominator,
  String path,
) {
  final result = Rational.create(
    _integer(numerator, '$path/numerator'),
    _integer(denominator, '$path/denominator'),
  );

  return _successValue(result, path);
}

StableId _stableId(Object? value, String path) {
  final result = StableId.create(_string(value, path));
  return _successValue(result, path);
}

StableId? _nullableStableId(Object? value, String path) {
  return value == null ? null : _stableId(value, path);
}

List<StableId> _stableIds(Object? value, String path) {
  final source = _objectList(value, path);

  return List<StableId>.unmodifiable(
    <StableId>[
      for (var index = 0; index < source.length; index++)
        _stableId(source[index], '$path/$index'),
    ],
  );
}

CalculationDate _date(Object? value, String path) {
  final result = CalculationDate.parse(_string(value, path));
  return _successValue(result, path);
}

CalculationDate? _nullableDate(Object? value, String path) {
  return value == null ? null : _date(value, path);
}

List<String> _strings(Object? value, String path) {
  final source = _objectList(value, path);

  return List<String>.unmodifiable(
    <String>[
      for (var index = 0; index < source.length; index++)
        _string(source[index], '$path/$index'),
    ],
  );
}

Map<String, Object?> _objectMap(Object? value, String path) {
  if (value is! Map) {
    throw FormatException('Expected object at $path.');
  }

  final result = <String, Object?>{};

  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('Expected string key at $path.');
    }

    result[entry.key as String] = entry.value;
  }

  return result;
}

List<Object?> _objectList(Object? value, String path) {
  if (value is! List) {
    throw FormatException('Expected array at $path.');
  }

  return List<Object?>.of(value);
}

String _string(Object? value, String path) {
  if (value is! String) {
    throw FormatException('Expected string at $path.');
  }

  return value;
}

String? _nullableString(Object? value, String path) {
  return value == null ? null : _string(value, path);
}

int _integer(Object? value, String path) {
  if (value is! int) {
    throw FormatException('Expected integer at $path.');
  }

  return value;
}

bool _boolean(Object? value, String path) {
  if (value is! bool) {
    throw FormatException('Expected boolean at $path.');
  }

  return value;
}

T _enumValue<T>(
  Iterable<T> values,
  Object? rawValue,
  String path,
  String Function(T value) stableValue,
) {
  final text = _string(rawValue, path);

  for (final value in values) {
    if (stableValue(value) == text) {
      return value;
    }
  }

  throw FormatException('Unknown enum value at $path.');
}

T _successValue<T>(AppResult<T> result, String path) {
  if (result is AppSuccess<T>) {
    return result.value;
  }

  throw FormatException('Invalid value at $path.');
}

final class _ConditionBudget {
  int nodeCount = 0;
}

import '../../../core/value_objects/calculation_date.dart';
import '../../../core/value_objects/money_yen.dart';
import '../../../core/value_objects/stable_id.dart';
import '../../../core/value_objects/validity_period.dart';
import 'catalog_entity.dart';
import 'catalog_types.dart';

/// A user-selectable payment instrument.
final class PaymentInstrument implements CatalogEntity {
  PaymentInstrument({
    required this.id,
    required this.name,
    required this.shortName,
    required this.instrumentType,
    required this.issuerName,
    required this.partnerInstitutionName,
    required Iterable<StableId> availableBrandIds,
    required this.annualFee,
    required Iterable<StableId> supportedModeIds,
    required Iterable<StableId> supportedRouteIds,
    required this.validityPeriod,
    required this.status,
    required Iterable<StableId> sourceIds,
    required this.lastVerifiedAt,
    required Iterable<String> displayClaims,
    required Iterable<StableId> tags,
    required Iterable<String> notes,
  })  : availableBrandIds = _freezeUniqueIds(
          availableBrandIds,
          'availableBrandIds',
        ),
        supportedModeIds = _freezeUniqueIds(
          supportedModeIds,
          'supportedModeIds',
        ),
        supportedRouteIds = _freezeUniqueIds(
          supportedRouteIds,
          'supportedRouteIds',
        ),
        sourceIds = _freezeUniqueIds(sourceIds, 'sourceIds'),
        displayClaims = _freezeUniqueText(
          displayClaims,
          'displayClaims',
        ),
        tags = _freezeUniqueIds(tags, 'tags'),
        notes = _freezeUniqueText(notes, 'notes') {
    _requireText(name, 'name');
    _requireText(shortName, 'shortName');
    _requireText(instrumentType, 'instrumentType');
    _requireText(issuerName, 'issuerName');
    if (partnerInstitutionName != null) {
      _requireText(
        partnerInstitutionName!,
        'partnerInstitutionName',
      );
    }
    if (annualFee.isNegative) {
      throw ArgumentError.value(
        annualFee,
        'annualFee',
        'Annual fee must not be negative.',
      );
    }
  }

  @override
  final StableId id;
  final String name;
  final String shortName;
  final String instrumentType;
  final String issuerName;
  final String? partnerInstitutionName;
  final List<StableId> availableBrandIds;
  final MoneyYen annualFee;
  final List<StableId> supportedModeIds;
  final List<StableId> supportedRouteIds;
  final ValidityPeriod validityPeriod;
  final CatalogItemStatus status;
  final List<StableId> sourceIds;
  final CalculationDate lastVerifiedAt;
  final List<String> displayClaims;
  final List<StableId> tags;
  final List<String> notes;
}

/// A payment mode belonging to one instrument.
final class PaymentMode implements CatalogEntity {
  PaymentMode({
    required this.id,
    required this.instrumentId,
    required this.name,
    required this.modeType,
    required Iterable<StableId> supportedRouteIds,
    required this.validityPeriod,
    required this.status,
    required Iterable<StableId> sourceIds,
    required Iterable<String> notes,
  })  : supportedRouteIds = _freezeUniqueIds(
          supportedRouteIds,
          'supportedRouteIds',
        ),
        sourceIds = _freezeUniqueIds(sourceIds, 'sourceIds'),
        notes = _freezeUniqueText(notes, 'notes') {
    _requireText(name, 'name');
  }

  @override
  final StableId id;
  final StableId instrumentId;
  final String name;
  final PaymentModeType modeType;
  final List<StableId> supportedRouteIds;
  final ValidityPeriod validityPeriod;
  final CatalogItemStatus status;
  final List<StableId> sourceIds;
  final List<String> notes;
}

/// A concrete route through which a payment is performed.
final class PaymentRoute implements CatalogEntity {
  PaymentRoute({
    required this.id,
    required this.name,
    required this.routeType,
    required Iterable<StableId> brandIds,
    required this.deviceRequirement,
    required Iterable<StableId> supportedInstrumentIds,
    required this.validityPeriod,
    required this.status,
    required Iterable<StableId> sourceIds,
    required Iterable<String> notes,
  })  : brandIds = _freezeUniqueIds(brandIds, 'brandIds'),
        supportedInstrumentIds = _freezeUniqueIds(
          supportedInstrumentIds,
          'supportedInstrumentIds',
        ),
        sourceIds = _freezeUniqueIds(sourceIds, 'sourceIds'),
        notes = _freezeUniqueText(notes, 'notes') {
    _requireText(name, 'name');
    _requireText(routeType, 'routeType');
    if (deviceRequirement != null) {
      _requireText(deviceRequirement!, 'deviceRequirement');
    }
  }

  @override
  final StableId id;
  final String name;
  final String routeType;
  final List<StableId> brandIds;
  final String? deviceRequirement;
  final List<StableId> supportedInstrumentIds;
  final ValidityPeriod validityPeriod;
  final CatalogItemStatus status;
  final List<StableId> sourceIds;
  final List<String> notes;
}

/// A funding or charging relationship between instruments.
final class FundingRelation implements CatalogEntity {
  FundingRelation({
    required this.id,
    required this.sourceInstrumentId,
    required this.destinationInstrumentId,
    required this.relationType,
    required this.validityPeriod,
    required this.status,
    required Iterable<StableId> sourceIds,
    required Iterable<String> notes,
  })  : sourceIds = _freezeUniqueIds(sourceIds, 'sourceIds'),
        notes = _freezeUniqueText(notes, 'notes') {
    _requireText(relationType, 'relationType');
  }

  @override
  final StableId id;
  final StableId sourceInstrumentId;
  final StableId destinationInstrumentId;
  final String relationType;
  final ValidityPeriod validityPeriod;
  final CatalogItemStatus status;
  final List<StableId> sourceIds;
  final List<String> notes;
}

List<StableId> _freezeUniqueIds(
  Iterable<StableId> values,
  String fieldName,
) {
  final result = List<StableId>.of(values);
  if (result.toSet().length != result.length) {
    throw ArgumentError.value(
      values,
      fieldName,
      'Values must be unique.',
    );
  }
  return List<StableId>.unmodifiable(result);
}

List<String> _freezeUniqueText(
  Iterable<String> values,
  String fieldName,
) {
  final result = List<String>.of(values);
  for (final value in result) {
    _requireText(value, fieldName);
  }
  if (result.toSet().length != result.length) {
    throw ArgumentError.value(
      values,
      fieldName,
      'Values must be unique.',
    );
  }
  return List<String>.unmodifiable(result);
}

void _requireText(String value, String fieldName) {
  if (value.isEmpty) {
    throw ArgumentError.value(
      value,
      fieldName,
      'Value must not be empty.',
    );
  }
}

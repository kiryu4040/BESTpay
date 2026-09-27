import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/validity_period.dart';
import 'package:bestpay/domain/catalog/models/catalog_entity.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';

/// A user-selectable payment instrument (catalog phase 1 subset).
///
/// Only the fields required by the phase-1 ranking are modelled. Payment
/// modes, routes, and funding relations keep their catalog files as empty
/// placeholders and are decoded in a later phase.
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
  })  : availableBrandIds = _freezeIds(
          availableBrandIds,
          'availableBrandIds',
        ),
        supportedModeIds = _freezeIds(
          supportedModeIds,
          'supportedModeIds',
        ),
        supportedRouteIds = _freezeIds(
          supportedRouteIds,
          'supportedRouteIds',
        ),
        sourceIds = _freezeIds(sourceIds, 'sourceIds'),
        displayClaims = _freezeText(displayClaims, 'displayClaims'),
        tags = _freezeIds(tags, 'tags'),
        notes = _freezeText(notes, 'notes') {
    _requireText(name, 'name');
    _requireText(shortName, 'shortName');
    _requireText(instrumentType, 'instrumentType');
    _requireText(issuerName, 'issuerName');

    final partner = partnerInstitutionName;
    if (partner != null) {
      _requireText(partner, 'partnerInstitutionName');
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

  /// Advertising claims kept separate from calculated values (D-52).
  final List<String> displayClaims;
  final List<StableId> tags;
  final List<String> notes;
}

List<StableId> _freezeIds(Iterable<StableId> values, String fieldName) {
  final result = List<StableId>.of(values);

  if (result.toSet().length != result.length) {
    throw ArgumentError.value(values, fieldName, 'Values must be unique.');
  }

  return List<StableId>.unmodifiable(result);
}

List<String> _freezeText(Iterable<String> values, String fieldName) {
  final result = List<String>.of(values);

  for (final value in result) {
    _requireText(value, fieldName);
  }

  if (result.toSet().length != result.length) {
    throw ArgumentError.value(values, fieldName, 'Values must be unique.');
  }

  return List<String>.unmodifiable(result);
}

void _requireText(String value, String fieldName) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, fieldName, 'Value must not be empty.');
  }
}

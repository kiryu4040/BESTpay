import '../../../core/value_objects/calculation_date.dart';
import '../../../core/value_objects/rational.dart';
import '../../../core/value_objects/stable_id.dart';
import 'catalog_entity.dart';
import 'catalog_types.dart';

/// Defines how one point is valued in Japanese yen.
sealed class PointValueDefinition {
  const PointValueDefinition();
}

/// A point value with an exact fixed yen conversion rate.
final class FixedPointValueDefinition extends PointValueDefinition {
  const FixedPointValueDefinition(this.yenPerPoint);

  final Rational yenPerPoint;
}

/// A point whose yen value depends on its redemption context.
final class VariablePointValueDefinition extends PointValueDefinition {
  const VariablePointValueDefinition();
}

/// A point whose yen value has not been configured.
final class UnsetPointValueDefinition extends PointValueDefinition {
  const UnsetPointValueDefinition();
}

/// Defines the expiration policy of a point program.
sealed class PointExpiration {
  const PointExpiration();
}

/// Points do not expire.
final class NoPointExpiration extends PointExpiration {
  const NoPointExpiration();
}

/// All represented points expire on one fixed date.
final class FixedDatePointExpiration extends PointExpiration {
  const FixedDatePointExpiration(this.expiresOn);

  final CalculationDate expiresOn;
}

/// Points expire after a positive number of months.
final class DurationMonthsPointExpiration extends PointExpiration {
  DurationMonthsPointExpiration(this.months) {
    if (months < 1) {
      throw ArgumentError.value(
        months,
        'months',
        'Expiration duration must be at least one month.',
      );
    }
  }

  final int months;
}

/// The expiration policy is unknown.
final class UnknownPointExpiration extends PointExpiration {
  const UnknownPointExpiration();
}

/// A catalog definition for one point program.
final class PointProgram implements CatalogEntity {
  PointProgram({
    required this.id,
    required this.name,
    required this.issuerName,
    required this.unitName,
    required this.valueDefinition,
    required this.expiration,
    required this.status,
    required Iterable<StableId> sourceIds,
    required this.lastVerifiedAt,
    required Iterable<String> notes,
  })  : sourceIds = _freezeUniqueIds(sourceIds, 'sourceIds'),
        notes = _freezeUniqueText(notes, 'notes') {
    _requireNonEmpty(name, 'name');
    _requireNonEmpty(issuerName, 'issuerName');
    _requireNonEmpty(unitName, 'unitName');
  }

  @override
  final StableId id;
  final String name;
  final String issuerName;
  final String unitName;
  final PointValueDefinition valueDefinition;
  final PointExpiration expiration;
  final CatalogItemStatus status;
  final List<StableId> sourceIds;
  final CalculationDate lastVerifiedAt;
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
    _requireNonEmpty(value, fieldName);
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

void _requireNonEmpty(String value, String fieldName) {
  if (value.isEmpty) {
    throw ArgumentError.value(
      value,
      fieldName,
      'Value must not be empty.',
    );
  }
}

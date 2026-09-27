import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/catalog/models/catalog_entity.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';

/// Defines how one point is valued in Japanese yen.
sealed class PointValueDefinition {
  const PointValueDefinition();

  /// Converts points into an exact yen value, if the value is fixed.
  ///
  /// Variable and unset point values return null so the caller can keep them
  /// out of the confirmed yen total instead of guessing (D-37, D-50).
  MicrosYen? valueOf(PointAmount points);
}

/// A point value with an exact fixed yen conversion rate.
final class FixedPointValueDefinition extends PointValueDefinition {
  const FixedPointValueDefinition(this.yenPerPoint);

  final Rational yenPerPoint;

  @override
  MicrosYen? valueOf(PointAmount points) {
    if (yenPerPoint.isNegative) {
      return null;
    }

    final micros = (BigInt.from(points.points) *
            BigInt.from(yenPerPoint.numerator) *
            BigInt.from(MicrosYen.microsPerYen)) ~/
        BigInt.from(yenPerPoint.denominator);

    return MicrosYen(micros.toInt());
  }
}

/// A point whose yen value depends on its redemption context.
final class VariablePointValueDefinition extends PointValueDefinition {
  const VariablePointValueDefinition();

  @override
  MicrosYen? valueOf(PointAmount points) => null;
}

/// A point whose yen value has not been configured.
final class UnsetPointValueDefinition extends PointValueDefinition {
  const UnsetPointValueDefinition();

  @override
  MicrosYen? valueOf(PointAmount points) => null;
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
  })  : sourceIds = _freezeIds(sourceIds, 'sourceIds'),
        notes = _freezeText(notes, 'notes') {
    _requireNonEmpty(name, 'name');
    _requireNonEmpty(issuerName, 'issuerName');
    _requireNonEmpty(unitName, 'unitName');
  }

  @override
  final StableId id;
  final String name;
  final String issuerName;

  /// The unit shown next to point amounts, for example `pt`.
  final String unitName;

  final PointValueDefinition valueDefinition;
  final PointExpiration expiration;
  final CatalogItemStatus status;
  final List<StableId> sourceIds;
  final CalculationDate lastVerifiedAt;
  final List<String> notes;

  /// Exact yen value of [points] under this program, or null when unknown.
  ///
  /// Points are never summed across programs; each program is converted on
  /// its own before the totals are combined (D-51).
  MicrosYen? valueOf(PointAmount points) => valueDefinition.valueOf(points);
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
    _requireNonEmpty(value, fieldName);
  }

  if (result.toSet().length != result.length) {
    throw ArgumentError.value(values, fieldName, 'Values must be unique.');
  }

  return List<String>.unmodifiable(result);
}

void _requireNonEmpty(String value, String fieldName) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, fieldName, 'Value must not be empty.');
  }
}

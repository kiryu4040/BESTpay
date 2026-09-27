import '../../../core/value_objects/rational.dart';
import '../../../core/value_objects/stable_id.dart';
import '../../../core/value_objects/tri_state.dart';
import '../../../core/value_objects/validity_period.dart';
import 'catalog_entity.dart';
import 'catalog_types.dart';

/// A catalog definition for one externally supplied or derived condition.
final class ConditionDefinition implements CatalogEntity {
  ConditionDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.valueType,
    required this.defaultState,
    required this.verificationMethod,
    required this.scope,
    required this.sensitivity,
    required this.validityPeriod,
    required this.status,
    required Iterable<StableId> sourceIds,
    required Iterable<String> notes,
  })  : sourceIds = _freezeUniqueIds(sourceIds, 'sourceIds'),
        notes = _freezeUniqueText(notes, 'notes') {
    _requireNonEmpty(name, 'name');
    _requireNonEmpty(valueType, 'valueType');
    _requireNonEmpty(scope, 'scope');
    _requireNonEmpty(sensitivity, 'sensitivity');
  }

  @override
  final StableId id;
  final String name;

  /// May be empty because the schema does not define a minimum length.
  final String description;

  final String valueType;
  final TriState defaultState;
  final ConditionVerificationMethod verificationMethod;
  final String scope;
  final String sensitivity;
  final ValidityPeriod validityPeriod;
  final CatalogItemStatus status;
  final List<StableId> sourceIds;
  final List<String> notes;
}

/// A typed condition tree.
///
/// Evaluation is intentionally deferred to a later PR.
sealed class ConditionExpression {
  const ConditionExpression();
}

/// Logical conjunction of one or more child expressions.
final class AllConditionExpression extends ConditionExpression {
  AllConditionExpression(Iterable<ConditionExpression> children)
      : children = _freezeChildren(children, 'children');

  final List<ConditionExpression> children;
}

/// Logical disjunction of one or more child expressions.
final class AnyConditionExpression extends ConditionExpression {
  AnyConditionExpression(Iterable<ConditionExpression> children)
      : children = _freezeChildren(children, 'children');

  final List<ConditionExpression> children;
}

/// Logical negation of one child expression.
final class NotConditionExpression extends ConditionExpression {
  const NotConditionExpression(this.child);

  final ConditionExpression child;
}

/// Reference to one condition definition.
final class ConditionReferenceExpression extends ConditionExpression {
  const ConditionReferenceExpression(this.conditionId);

  final StableId conditionId;
}

/// Comparison against a typed literal value.
final class ComparisonConditionExpression extends ConditionExpression {
  const ComparisonConditionExpression({
    required this.conditionId,
    required this.operator,
    required this.value,
  });

  final StableId conditionId;
  final ComparisonOperator operator;
  final ConditionComparisonValue value;
}

/// A value accepted by the comparison node schema.
sealed class ConditionComparisonValue {
  const ConditionComparisonValue();
}

final class StringConditionComparisonValue extends ConditionComparisonValue {
  const StringConditionComparisonValue(this.value);

  final String value;
}

final class IntegerConditionComparisonValue extends ConditionComparisonValue {
  const IntegerConditionComparisonValue(this.value);

  final int value;
}

final class BooleanConditionComparisonValue extends ConditionComparisonValue {
  const BooleanConditionComparisonValue(this.value);

  final bool value;
}

final class NullConditionComparisonValue extends ConditionComparisonValue {
  const NullConditionComparisonValue();
}

final class RationalConditionComparisonValue extends ConditionComparisonValue {
  const RationalConditionComparisonValue(this.value);

  final Rational value;
}

/// A unique list containing only String, int, or bool values.
final class ListConditionComparisonValue extends ConditionComparisonValue {
  ListConditionComparisonValue(Iterable<Object> values)
      : values = _freezeComparisonValues(values);

  final List<Object> values;
}

List<ConditionExpression> _freezeChildren(
  Iterable<ConditionExpression> values,
  String fieldName,
) {
  final result = List<ConditionExpression>.of(values);

  if (result.isEmpty) {
    throw ArgumentError.value(
      values,
      fieldName,
      'At least one child is required.',
    );
  }

  return List<ConditionExpression>.unmodifiable(result);
}

List<Object> _freezeComparisonValues(Iterable<Object> values) {
  final result = List<Object>.of(values);

  for (final value in result) {
    if (value is! String && value is! int && value is! bool) {
      throw ArgumentError.value(
        value,
        'values',
        'Only String, int, and bool values are supported.',
      );
    }
  }

  if (result.toSet().length != result.length) {
    throw ArgumentError.value(
      values,
      'values',
      'Values must be unique.',
    );
  }

  return List<Object>.unmodifiable(result);
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

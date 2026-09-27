import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';

/// Immutable condition values supplied to a reward calculation.
///
/// [states] are used by condition-reference nodes. [values] are used by
/// comparison nodes. A missing map entry is distinct from a present null value.
final class ConditionEvaluationContext {
  ConditionEvaluationContext({
    Map<StableId, TriState> states = const <StableId, TriState>{},
    Map<StableId, Object?> values = const <StableId, Object?>{},
  })  : states = Map<StableId, TriState>.unmodifiable(states),
        values = Map<StableId, Object?>.unmodifiable(values) {
    for (final entry in this.values.entries) {
      if (!_isSupportedValue(entry.value)) {
        throw ArgumentError.value(
          entry.value,
          'values',
          'Condition values must be String, int, bool, Rational, or null.',
        );
      }
    }
  }

  final Map<StableId, TriState> states;
  final Map<StableId, Object?> values;

  bool containsValue(StableId conditionId) {
    return values.containsKey(conditionId);
  }

  Object? valueOf(StableId conditionId) {
    return values[conditionId];
  }

  TriState stateOf(StableId conditionId) {
    return states[conditionId] ?? TriState.unknown;
  }

  static bool _isSupportedValue(Object? value) {
    return value == null ||
        value is String ||
        value is int ||
        value is bool ||
        value is Rational;
  }
}

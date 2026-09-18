import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TriState', () {
    test('has stable names instead of relying on enum indexes', () {
      expect(TriState.satisfied.name, 'satisfied');
      expect(TriState.notSatisfied.name, 'notSatisfied');
      expect(TriState.unknown.name, 'unknown');
      expect(TriState.notApplicable.name, 'notApplicable');
    });

    test('NOT follows the complete four-valued truth table', () {
      expect(TriState.satisfied.not, TriState.notSatisfied);
      expect(TriState.notSatisfied.not, TriState.satisfied);
      expect(TriState.unknown.not, TriState.unknown);
      expect(TriState.notApplicable.not, TriState.notApplicable);
    });

    test('AND follows the complete four-valued truth table', () {
      const cases = <(TriState, TriState, TriState)>[
        (TriState.satisfied, TriState.satisfied, TriState.satisfied),
        (TriState.satisfied, TriState.notSatisfied, TriState.notSatisfied),
        (TriState.satisfied, TriState.unknown, TriState.unknown),
        (TriState.satisfied, TriState.notApplicable, TriState.notApplicable),
        (TriState.notSatisfied, TriState.satisfied, TriState.notSatisfied),
        (TriState.notSatisfied, TriState.notSatisfied, TriState.notSatisfied),
        (TriState.notSatisfied, TriState.unknown, TriState.notSatisfied),
        (TriState.notSatisfied, TriState.notApplicable, TriState.notSatisfied),
        (TriState.unknown, TriState.satisfied, TriState.unknown),
        (TriState.unknown, TriState.notSatisfied, TriState.notSatisfied),
        (TriState.unknown, TriState.unknown, TriState.unknown),
        (TriState.unknown, TriState.notApplicable, TriState.unknown),
        (TriState.notApplicable, TriState.satisfied, TriState.notApplicable),
        (TriState.notApplicable, TriState.notSatisfied, TriState.notSatisfied),
        (TriState.notApplicable, TriState.unknown, TriState.unknown),
        (
          TriState.notApplicable,
          TriState.notApplicable,
          TriState.notApplicable,
        ),
      ];

      for (final entry in cases) {
        expect(
          entry.$1.and(entry.$2),
          entry.$3,
          reason: '${entry.$1.name} AND ${entry.$2.name}',
        );
      }
    });

    test('OR follows the complete four-valued truth table', () {
      const cases = <(TriState, TriState, TriState)>[
        (TriState.satisfied, TriState.satisfied, TriState.satisfied),
        (TriState.satisfied, TriState.notSatisfied, TriState.satisfied),
        (TriState.satisfied, TriState.unknown, TriState.satisfied),
        (TriState.satisfied, TriState.notApplicable, TriState.satisfied),
        (TriState.notSatisfied, TriState.satisfied, TriState.satisfied),
        (TriState.notSatisfied, TriState.notSatisfied, TriState.notSatisfied),
        (TriState.notSatisfied, TriState.unknown, TriState.unknown),
        (TriState.notSatisfied, TriState.notApplicable, TriState.notApplicable),
        (TriState.unknown, TriState.satisfied, TriState.satisfied),
        (TriState.unknown, TriState.notSatisfied, TriState.unknown),
        (TriState.unknown, TriState.unknown, TriState.unknown),
        (TriState.unknown, TriState.notApplicable, TriState.unknown),
        (TriState.notApplicable, TriState.satisfied, TriState.satisfied),
        (TriState.notApplicable, TriState.notSatisfied, TriState.notApplicable),
        (TriState.notApplicable, TriState.unknown, TriState.unknown),
        (
          TriState.notApplicable,
          TriState.notApplicable,
          TriState.notApplicable,
        ),
      ];

      for (final entry in cases) {
        expect(
          entry.$1.or(entry.$2),
          entry.$3,
          reason: '${entry.$1.name} OR ${entry.$2.name}',
        );
      }
    });

    test('nullable boolean conversion documents its lossy boundary', () {
      expect(TriState.satisfied.toNullableBool(), isTrue);
      expect(TriState.notSatisfied.toNullableBool(), isFalse);
      expect(TriState.unknown.toNullableBool(), isNull);
      expect(TriState.notApplicable.toNullableBool(), isNull);

      expect(TriState.fromNullableBool(true), TriState.satisfied);
      expect(TriState.fromNullableBool(false), TriState.notSatisfied);
      expect(TriState.fromNullableBool(null), TriState.unknown);
    });

    test('unknown and notApplicable remain distinct enum values', () {
      expect(TriState.unknown, isNot(TriState.notApplicable));
      expect(TriState.unknown.name, isNot(TriState.notApplicable.name));
    });
  });
}

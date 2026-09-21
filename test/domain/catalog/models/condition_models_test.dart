import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/core/value_objects/validity_period.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/condition_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConditionDefinition', () {
    test('stores typed values and defensively copies collections', () {
      final sourceIds = <StableId>[_id('source_one')];
      final notes = <String>['verified'];

      final definition = ConditionDefinition(
        id: _id('condition_one'),
        name: 'Condition One',
        description: '',
        valueType: 'boolean',
        defaultState: TriState.unknown,
        verificationMethod: ConditionVerificationMethod.userInput,
        scope: 'user',
        sensitivity: 'normal',
        validityPeriod: _period(),
        status: CatalogItemStatus.active,
        sourceIds: sourceIds,
        notes: notes,
      );

      sourceIds.add(_id('source_two'));
      notes.add('changed');

      expect(definition.description, isEmpty);
      expect(definition.defaultState, TriState.unknown);
      expect(
        definition.verificationMethod,
        ConditionVerificationMethod.userInput,
      );
      expect(definition.sourceIds, <StableId>[_id('source_one')]);
      expect(definition.notes, <String>['verified']);
      expect(
        () => definition.sourceIds.add(_id('source_three')),
        throwsUnsupportedError,
      );
    });

    test('rejects blank schema-constrained text', () {
      expect(
        () => _definition(name: ''),
        throwsArgumentError,
      );
      expect(
        () => _definition(valueType: ''),
        throwsArgumentError,
      );
      expect(
        () => _definition(scope: ''),
        throwsArgumentError,
      );
      expect(
        () => _definition(sensitivity: ''),
        throwsArgumentError,
      );
    });
  });

  group('ConditionExpression', () {
    test('represents all, any, not, and condition nodes', () {
      final leaf = ConditionReferenceExpression(_id('condition_one'));
      final notNode = NotConditionExpression(leaf);
      final anyNode = AnyConditionExpression(<ConditionExpression>[
        leaf,
        notNode,
      ]);
      final children = <ConditionExpression>[leaf, anyNode];
      final allNode = AllConditionExpression(children);

      children.add(leaf);

      expect(allNode.children.length, 2);
      expect(allNode.children.first, same(leaf));
      expect(anyNode.children.length, 2);
      expect(notNode.child, same(leaf));
      expect(
        () => allNode.children.add(leaf),
        throwsUnsupportedError,
      );
    });

    test('requires at least one child for all and any nodes', () {
      expect(
        () => AllConditionExpression(const <ConditionExpression>[]),
        throwsArgumentError,
      );
      expect(
        () => AnyConditionExpression(const <ConditionExpression>[]),
        throwsArgumentError,
      );
    });

    test('represents every scalar comparison value', () {
      final stringNode = _comparison(
        const StringConditionComparisonValue('gold'),
      );
      final integerNode = _comparison(
        const IntegerConditionComparisonValue(10),
      );
      final booleanNode = _comparison(
        const BooleanConditionComparisonValue(true),
      );
      final nullNode = _comparison(
        const NullConditionComparisonValue(),
      );
      final rationalNode = _comparison(
        RationalConditionComparisonValue(_rational(3, 2)),
      );

      expect(
        stringNode.value,
        isA<StringConditionComparisonValue>(),
      );
      expect(
        integerNode.value,
        isA<IntegerConditionComparisonValue>(),
      );
      expect(
        booleanNode.value,
        isA<BooleanConditionComparisonValue>(),
      );
      expect(
        nullNode.value,
        isA<NullConditionComparisonValue>(),
      );
      expect(
        rationalNode.value,
        isA<RationalConditionComparisonValue>(),
      );
    });

    test('freezes list comparison values', () {
      final values = <Object>['gold', 10, true];
      final comparisonValue = ListConditionComparisonValue(values);

      values.add('changed');

      expect(comparisonValue.values, <Object>['gold', 10, true]);
      expect(
        () => comparisonValue.values.add(false),
        throwsUnsupportedError,
      );
    });

    test('allows an empty comparison list', () {
      final value = ListConditionComparisonValue(const <Object>[]);

      expect(value.values, isEmpty);
    });

    test('rejects duplicate or unsupported comparison list values', () {
      expect(
        () => ListConditionComparisonValue(<Object>['gold', 'gold']),
        throwsArgumentError,
      );
      expect(
        () => ListConditionComparisonValue(<Object>[1.5]),
        throwsArgumentError,
      );
    });

    test('preserves comparison operator stable value', () {
      final node = ComparisonConditionExpression(
        conditionId: _id('condition_one'),
        operator: ComparisonOperator.greaterThanOrEqual,
        value: const IntegerConditionComparisonValue(10),
      );

      expect(node.operator.value, 'greaterThanOrEqual');
      expect(node.conditionId, _id('condition_one'));
    });
  });
}

ConditionDefinition _definition({
  String name = 'Condition One',
  String valueType = 'boolean',
  String scope = 'user',
  String sensitivity = 'normal',
}) {
  return ConditionDefinition(
    id: _id('condition_one'),
    name: name,
    description: '',
    valueType: valueType,
    defaultState: TriState.unknown,
    verificationMethod: ConditionVerificationMethod.userInput,
    scope: scope,
    sensitivity: sensitivity,
    validityPeriod: _period(),
    status: CatalogItemStatus.active,
    sourceIds: const <StableId>[],
    notes: const <String>[],
  );
}

ComparisonConditionExpression _comparison(
  ConditionComparisonValue value,
) {
  return ComparisonConditionExpression(
    conditionId: _id('condition_one'),
    operator: ComparisonOperator.equals,
    value: value,
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

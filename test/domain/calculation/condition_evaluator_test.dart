import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/calculation/condition_evaluator.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/condition_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = ConditionEvaluator();

  group('ConditionEvaluationContext', () {
    test('defensively copies and freezes maps', () {
      final conditionId = _id('condition_one');
      final states = <StableId, TriState>{
        conditionId: TriState.satisfied,
      };
      final values = <StableId, Object?>{
        conditionId: 10,
      };

      final context = ConditionEvaluationContext(
        states: states,
        values: values,
      );

      states[conditionId] = TriState.notSatisfied;
      values[conditionId] = 20;

      expect(context.stateOf(conditionId), TriState.satisfied);
      expect(context.valueOf(conditionId), 10);
      expect(
        () => context.states[conditionId] = TriState.unknown,
        throwsUnsupportedError,
      );
      expect(
        () => context.values[conditionId] = 30,
        throwsUnsupportedError,
      );
    });

    test('distinguishes missing values from present null values', () {
      final nullId = _id('condition_null');
      final missingId = _id('condition_missing');
      final context = ConditionEvaluationContext(
        values: <StableId, Object?>{
          nullId: null,
        },
      );

      expect(context.containsValue(nullId), isTrue);
      expect(context.valueOf(nullId), isNull);
      expect(context.containsValue(missingId), isFalse);
    });

    test('rejects unsupported comparison input types', () {
      expect(
        () => ConditionEvaluationContext(
          values: <StableId, Object?>{
            _id('condition_list'): <int>[1, 2],
          },
        ),
        throwsArgumentError,
      );
    });
  });

  group('ConditionEvaluator logical nodes', () {
    test('returns unknown for a missing condition state', () {
      final expression = ConditionReferenceExpression(
        _id('condition_missing'),
      );

      expect(
        _success(
          evaluator.evaluate(
            expression,
            ConditionEvaluationContext(),
          ),
        ),
        TriState.unknown,
      );
    });

    test('evaluates all, any, and not with four-state logic', () {
      final satisfiedId = _id('condition_yes');
      final failedId = _id('condition_no');
      final unknownId = _id('condition_unknown');
      final notApplicableId = _id('condition_na');

      final context = ConditionEvaluationContext(
        states: <StableId, TriState>{
          satisfiedId: TriState.satisfied,
          failedId: TriState.notSatisfied,
          unknownId: TriState.unknown,
          notApplicableId: TriState.notApplicable,
        },
      );

      final all = AllConditionExpression(<ConditionExpression>[
        ConditionReferenceExpression(satisfiedId),
        ConditionReferenceExpression(notApplicableId),
      ]);
      final any = AnyConditionExpression(<ConditionExpression>[
        ConditionReferenceExpression(failedId),
        ConditionReferenceExpression(unknownId),
      ]);
      final not = NotConditionExpression(
        ConditionReferenceExpression(failedId),
      );

      expect(_success(evaluator.evaluate(all, context)), TriState.satisfied);
      expect(_success(evaluator.evaluate(any, context)), TriState.unknown);
      expect(_success(evaluator.evaluate(not, context)), TriState.satisfied);
    });

    test('returns notApplicable when all children are notApplicable', () {
      final firstId = _id('condition_na_one');
      final secondId = _id('condition_na_two');
      final context = ConditionEvaluationContext(
        states: <StableId, TriState>{
          firstId: TriState.notApplicable,
          secondId: TriState.notApplicable,
        },
      );

      expect(
        _success(
          evaluator.evaluate(
            AllConditionExpression(<ConditionExpression>[
              ConditionReferenceExpression(firstId),
              ConditionReferenceExpression(secondId),
            ]),
            context,
          ),
        ),
        TriState.notApplicable,
      );

      expect(
        _success(
          evaluator.evaluate(
            AnyConditionExpression(<ConditionExpression>[
              ConditionReferenceExpression(firstId),
              ConditionReferenceExpression(secondId),
            ]),
            context,
          ),
        ),
        TriState.notApplicable,
      );
    });
  });

  group('ConditionEvaluator comparisons', () {
    test('evaluates equality for every scalar type and null', () {
      final stringId = _id('condition_string');
      final integerId = _id('condition_integer');
      final booleanId = _id('condition_boolean');
      final rationalId = _id('condition_rational');
      final nullId = _id('condition_null');

      final half = _rational(1, 2);
      final context = ConditionEvaluationContext(
        values: <StableId, Object?>{
          stringId: 'gold',
          integerId: 100,
          booleanId: true,
          rationalId: half,
          nullId: null,
        },
      );

      expect(
        _compare(
          evaluator,
          context,
          stringId,
          ComparisonOperator.equals,
          const StringConditionComparisonValue('gold'),
        ),
        TriState.satisfied,
      );
      expect(
        _compare(
          evaluator,
          context,
          integerId,
          ComparisonOperator.notEquals,
          const IntegerConditionComparisonValue(99),
        ),
        TriState.satisfied,
      );
      expect(
        _compare(
          evaluator,
          context,
          booleanId,
          ComparisonOperator.equals,
          const BooleanConditionComparisonValue(true),
        ),
        TriState.satisfied,
      );
      expect(
        _compare(
          evaluator,
          context,
          rationalId,
          ComparisonOperator.equals,
          RationalConditionComparisonValue(half),
        ),
        TriState.satisfied,
      );
      expect(
        _compare(
          evaluator,
          context,
          nullId,
          ComparisonOperator.equals,
          const NullConditionComparisonValue(),
        ),
        TriState.satisfied,
      );
    });

    test('evaluates ordered integer and rational comparisons', () {
      final integerId = _id('condition_integer');
      final rationalId = _id('condition_rational');
      final context = ConditionEvaluationContext(
        values: <StableId, Object?>{
          integerId: 10,
          rationalId: _rational(3, 2),
        },
      );

      final integerCases = <ComparisonOperator, int>{
        ComparisonOperator.greaterThan: 9,
        ComparisonOperator.greaterThanOrEqual: 10,
        ComparisonOperator.lessThan: 11,
        ComparisonOperator.lessThanOrEqual: 10,
      };

      for (final entry in integerCases.entries) {
        expect(
          _compare(
            evaluator,
            context,
            integerId,
            entry.key,
            IntegerConditionComparisonValue(entry.value),
          ),
          TriState.satisfied,
        );
      }

      expect(
        _compare(
          evaluator,
          context,
          rationalId,
          ComparisonOperator.greaterThan,
          RationalConditionComparisonValue(_rational(4, 3)),
        ),
        TriState.satisfied,
      );
    });

    test('evaluates in and notIn membership', () {
      final conditionId = _id('condition_level');
      final context = ConditionEvaluationContext(
        values: <StableId, Object?>{
          conditionId: 'gold',
        },
      );
      final allowed = ListConditionComparisonValue(
        const <Object>['gold', 'platinum'],
      );

      expect(
        _compare(
          evaluator,
          context,
          conditionId,
          ComparisonOperator.inSet,
          allowed,
        ),
        TriState.satisfied,
      );
      expect(
        _compare(
          evaluator,
          context,
          conditionId,
          ComparisonOperator.notInSet,
          allowed,
        ),
        TriState.notSatisfied,
      );
    });

    test('returns unknown when comparison input is missing', () {
      final result = evaluator.evaluate(
        ComparisonConditionExpression(
          conditionId: _id('condition_missing'),
          operator: ComparisonOperator.equals,
          value: const IntegerConditionComparisonValue(1),
        ),
        ConditionEvaluationContext(),
      );

      expect(_success(result), TriState.unknown);
    });

    test('fails for mixed types and invalid operators', () {
      final conditionId = _id('condition_value');
      final context = ConditionEvaluationContext(
        values: <StableId, Object?>{
          conditionId: 10,
        },
      );

      final mixedType = evaluator.evaluate(
        ComparisonConditionExpression(
          conditionId: conditionId,
          operator: ComparisonOperator.equals,
          value: const StringConditionComparisonValue('10'),
        ),
        context,
      );
      final invalidOrder = evaluator.evaluate(
        ComparisonConditionExpression(
          conditionId: conditionId,
          operator: ComparisonOperator.greaterThan,
          value: const StringConditionComparisonValue('9'),
        ),
        context,
      );

      expect(
        _failure(mixedType).code,
        AppErrorCode.calculationInputInvalid,
      );
      expect(
        _failure(invalidOrder).code,
        AppErrorCode.calculationInputInvalid,
      );
    });
  });

  group('ConditionEvaluator safety limits', () {
    test('accepts depth 10 and rejects depth 11', () {
      final conditionId = _id('condition_depth');
      final context = ConditionEvaluationContext(
        states: <StableId, TriState>{
          conditionId: TriState.satisfied,
        },
      );

      ConditionExpression depth10 = ConditionReferenceExpression(conditionId);
      for (var index = 1; index < 10; index++) {
        depth10 = NotConditionExpression(depth10);
      }

      ConditionExpression depth11 = depth10;
      depth11 = NotConditionExpression(depth11);

      expect(
        evaluator.evaluate(depth10, context),
        isA<AppSuccess<TriState>>(),
      );
      expect(
        _failure(evaluator.evaluate(depth11, context)).code,
        AppErrorCode.calculationRuleInvalid,
      );
    });

    test('accepts 100 nodes and rejects 101 nodes', () {
      final conditionId = _id('condition_nodes');
      final context = ConditionEvaluationContext(
        states: <StableId, TriState>{
          conditionId: TriState.satisfied,
        },
      );

      final hundredNodes = AllConditionExpression(
        List<ConditionExpression>.generate(
          99,
          (_) => ConditionReferenceExpression(conditionId),
        ),
      );
      final hundredOneNodes = AllConditionExpression(
        List<ConditionExpression>.generate(
          100,
          (_) => ConditionReferenceExpression(conditionId),
        ),
      );

      expect(
        evaluator.evaluate(hundredNodes, context),
        isA<AppSuccess<TriState>>(),
      );
      expect(
        _failure(evaluator.evaluate(hundredOneNodes, context)).code,
        AppErrorCode.calculationRuleInvalid,
      );
    });
  });
}

TriState _compare(
  ConditionEvaluator evaluator,
  ConditionEvaluationContext context,
  StableId conditionId,
  ComparisonOperator operator,
  ConditionComparisonValue value,
) {
  return _success(
    evaluator.evaluate(
      ComparisonConditionExpression(
        conditionId: conditionId,
        operator: operator,
        value: value,
      ),
      context,
    ),
  );
}

TriState _success(AppResult<TriState> result) {
  expect(result, isA<AppSuccess<TriState>>());
  return (result as AppSuccess<TriState>).value;
}

dynamic _failure(AppResult<TriState> result) {
  expect(result, isA<AppFailure<TriState>>());
  return (result as AppFailure<TriState>).error;
}

StableId _id(String value) {
  final result = StableId.create(value);
  expect(result, isA<AppSuccess<StableId>>());
  return (result as AppSuccess<StableId>).value;
}

Rational _rational(int numerator, int denominator) {
  final result = Rational.create(numerator, denominator);
  expect(result, isA<AppSuccess<Rational>>());
  return (result as AppSuccess<Rational>).value;
}

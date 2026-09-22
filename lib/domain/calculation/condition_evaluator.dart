import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/condition_models.dart';

/// Evaluates typed condition trees without using the call stack.
final class ConditionEvaluator {
  const ConditionEvaluator({
    this.maximumDepth = 10,
    this.maximumNodeCount = 100,
  })  : assert(maximumDepth > 0),
        assert(maximumNodeCount > 0);

  final int maximumDepth;
  final int maximumNodeCount;

  AppResult<TriState> evaluate(
    ConditionExpression expression,
    ConditionEvaluationContext context,
  ) {
    try {
      return AppSuccess<TriState>(
        _evaluate(expression, context),
      );
    } on _ConditionEvaluationException catch (error) {
      return AppFailure<TriState>(
        AppError(
          code: error.code,
          operation: 'calculation.condition.evaluate',
          context: error.context,
          causeType: error.runtimeType.toString(),
        ),
      );
    }
  }

  TriState _evaluate(
    ConditionExpression root,
    ConditionEvaluationContext context,
  ) {
    final frames = <_EvaluationFrame>[
      _EvaluationFrame(
        expression: root,
        depth: 1,
        expanded: false,
      ),
    ];
    final results = Map<ConditionExpression, TriState>.identity();
    var nodeCount = 0;

    while (frames.isNotEmpty) {
      final frame = frames.removeLast();
      final expression = frame.expression;

      if (!frame.expanded) {
        nodeCount += 1;

        if (nodeCount > maximumNodeCount) {
          throw _ConditionEvaluationException(
            AppErrorCode.calculationRuleInvalid,
            <String, Object?>{
              'field': 'conditionExpression',
              'limit': maximumNodeCount,
              'reason': 'nodeLimitExceeded',
            },
          );
        }

        if (frame.depth > maximumDepth) {
          throw _ConditionEvaluationException(
            AppErrorCode.calculationRuleInvalid,
            <String, Object?>{
              'field': 'conditionExpression',
              'limit': maximumDepth,
              'reason': 'depthLimitExceeded',
            },
          );
        }

        switch (expression) {
          case ConditionReferenceExpression():
            results[expression] = context.stateOf(expression.conditionId);

          case ComparisonConditionExpression():
            results[expression] = _evaluateComparison(
              expression,
              context,
            );

          case NotConditionExpression():
            frames
              ..add(
                _EvaluationFrame(
                  expression: expression,
                  depth: frame.depth,
                  expanded: true,
                ),
              )
              ..add(
                _EvaluationFrame(
                  expression: expression.child,
                  depth: frame.depth + 1,
                  expanded: false,
                ),
              );

          case AllConditionExpression():
            frames.add(
              _EvaluationFrame(
                expression: expression,
                depth: frame.depth,
                expanded: true,
              ),
            );
            for (var index = expression.children.length - 1;
                index >= 0;
                index--) {
              frames.add(
                _EvaluationFrame(
                  expression: expression.children[index],
                  depth: frame.depth + 1,
                  expanded: false,
                ),
              );
            }

          case AnyConditionExpression():
            frames.add(
              _EvaluationFrame(
                expression: expression,
                depth: frame.depth,
                expanded: true,
              ),
            );
            for (var index = expression.children.length - 1;
                index >= 0;
                index--) {
              frames.add(
                _EvaluationFrame(
                  expression: expression.children[index],
                  depth: frame.depth + 1,
                  expanded: false,
                ),
              );
            }
        }

        continue;
      }

      switch (expression) {
        case NotConditionExpression():
          results[expression] = _requiredResult(
            results,
            expression.child,
          ).not;

        case AllConditionExpression():
          var result = TriState.notApplicable;
          for (final child in expression.children) {
            result = result.and(_requiredResult(results, child));
          }
          results[expression] = result;

        case AnyConditionExpression():
          var result = TriState.notApplicable;
          for (final child in expression.children) {
            result = result.or(_requiredResult(results, child));
          }
          results[expression] = result;

        case ConditionReferenceExpression():
        case ComparisonConditionExpression():
          throw const _ConditionEvaluationException(
            AppErrorCode.calculationRuleInvalid,
            <String, Object?>{
              'field': 'conditionExpression',
              'reason': 'invalidTraversalState',
            },
          );
      }
    }

    return _requiredResult(results, root);
  }

  TriState _evaluateComparison(
    ComparisonConditionExpression expression,
    ConditionEvaluationContext context,
  ) {
    if (!context.containsValue(expression.conditionId)) {
      return TriState.unknown;
    }

    final actual = context.valueOf(expression.conditionId);

    return switch (expression.operator) {
      ComparisonOperator.equals => _equality(
          actual,
          expression.value,
          negate: false,
          expression: expression,
        ),
      ComparisonOperator.notEquals => _equality(
          actual,
          expression.value,
          negate: true,
          expression: expression,
        ),
      ComparisonOperator.greaterThan => _ordered(
          actual,
          expression.value,
          expression: expression,
          predicate: (comparison) => comparison > 0,
        ),
      ComparisonOperator.greaterThanOrEqual => _ordered(
          actual,
          expression.value,
          expression: expression,
          predicate: (comparison) => comparison >= 0,
        ),
      ComparisonOperator.lessThan => _ordered(
          actual,
          expression.value,
          expression: expression,
          predicate: (comparison) => comparison < 0,
        ),
      ComparisonOperator.lessThanOrEqual => _ordered(
          actual,
          expression.value,
          expression: expression,
          predicate: (comparison) => comparison <= 0,
        ),
      ComparisonOperator.inSet => _membership(
          actual,
          expression.value,
          negate: false,
          expression: expression,
        ),
      ComparisonOperator.notInSet => _membership(
          actual,
          expression.value,
          negate: true,
          expression: expression,
        ),
    };
  }

  TriState _equality(
    Object? actual,
    ConditionComparisonValue expectedValue, {
    required bool negate,
    required ComparisonConditionExpression expression,
  }) {
    if (expectedValue is ListConditionComparisonValue) {
      _invalidComparison(expression, actual, expectedValue);
    }

    final expected = _scalarValue(expectedValue);

    if (!_sameSupportedType(actual, expected)) {
      _invalidComparison(expression, actual, expectedValue);
    }

    final equals = actual == expected;
    return _state(negate ? !equals : equals);
  }

  TriState _ordered(
    Object? actual,
    ConditionComparisonValue expectedValue, {
    required ComparisonConditionExpression expression,
    required bool Function(int comparison) predicate,
  }) {
    final expected = _scalarValue(expectedValue);
    final comparison = switch ((actual, expected)) {
      (int left, int right) => left.compareTo(right),
      (Rational left, Rational right) => left.compareTo(right),
      _ => _invalidComparison(expression, actual, expectedValue),
    };

    return _state(predicate(comparison));
  }

  TriState _membership(
    Object? actual,
    ConditionComparisonValue expectedValue, {
    required bool negate,
    required ComparisonConditionExpression expression,
  }) {
    if (expectedValue is! ListConditionComparisonValue ||
        (actual is! String && actual is! int && actual is! bool)) {
      _invalidComparison(expression, actual, expectedValue);
    }

    final contains = expectedValue.values.contains(actual);
    return _state(negate ? !contains : contains);
  }

  Object? _scalarValue(ConditionComparisonValue value) {
    return switch (value) {
      StringConditionComparisonValue() => value.value,
      IntegerConditionComparisonValue() => value.value,
      BooleanConditionComparisonValue() => value.value,
      NullConditionComparisonValue() => null,
      RationalConditionComparisonValue() => value.value,
      ListConditionComparisonValue() => value.values,
    };
  }

  bool _sameSupportedType(Object? left, Object? right) {
    if (left == null || right == null) {
      return left == null && right == null;
    }

    return (left is String && right is String) ||
        (left is int && right is int) ||
        (left is bool && right is bool) ||
        (left is Rational && right is Rational);
  }

  Never _invalidComparison(
    ComparisonConditionExpression expression,
    Object? actual,
    ConditionComparisonValue expected,
  ) {
    throw _ConditionEvaluationException(
      AppErrorCode.calculationInputInvalid,
      <String, Object?>{
        'conditionId': expression.conditionId.value,
        'operator': expression.operator.value,
        'actualType': actual?.runtimeType.toString() ?? 'null',
        'expectedType': expected.runtimeType.toString(),
      },
    );
  }

  TriState _requiredResult(
    Map<ConditionExpression, TriState> results,
    ConditionExpression expression,
  ) {
    final result = results[expression];
    if (result == null) {
      throw const _ConditionEvaluationException(
        AppErrorCode.calculationRuleInvalid,
        <String, Object?>{
          'field': 'conditionExpression',
          'reason': 'missingEvaluationResult',
        },
      );
    }
    return result;
  }

  TriState _state(bool value) {
    return value ? TriState.satisfied : TriState.notSatisfied;
  }
}

final class _EvaluationFrame {
  const _EvaluationFrame({
    required this.expression,
    required this.depth,
    required this.expanded,
  });

  final ConditionExpression expression;
  final int depth;
  final bool expanded;
}

final class _ConditionEvaluationException implements Exception {
  const _ConditionEvaluationException(this.code, this.context);

  final AppErrorCode code;
  final Map<String, Object?> context;
}

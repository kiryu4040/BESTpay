import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/point_program_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PointValueDefinition', () {
    test('represents all schema variants', () {
      const fixed = FixedPointValueDefinition(Rational.one);
      const variable = VariablePointValueDefinition();
      const unset = UnsetPointValueDefinition();

      expect(fixed.yenPerPoint, Rational.one);
      expect(variable, isA<PointValueDefinition>());
      expect(unset, isA<PointValueDefinition>());
    });

    test('preserves an exact rational value', () {
      final ratio = _rational(3, 2);
      final definition = FixedPointValueDefinition(ratio);

      expect(definition.yenPerPoint, ratio);
      expect(definition.yenPerPoint.toString(), '3/2');
    });
  });

  group('PointExpiration', () {
    test('represents all schema variants', () {
      const none = NoPointExpiration();
      final fixedDate = FixedDatePointExpiration(_date('2027-01-01'));
      final duration = DurationMonthsPointExpiration(12);
      const unknown = UnknownPointExpiration();

      expect(none, isA<PointExpiration>());
      expect(fixedDate.expiresOn, _date('2027-01-01'));
      expect(duration.months, 12);
      expect(unknown, isA<PointExpiration>());
    });

    test('rejects a duration shorter than one month', () {
      expect(
        () => DurationMonthsPointExpiration(0),
        throwsArgumentError,
      );
      expect(
        () => DurationMonthsPointExpiration(-1),
        throwsArgumentError,
      );
    });
  });

  group('PointProgram', () {
    test('stores typed fields and defensively copies collections', () {
      final sourceIds = <StableId>[_id('source_one')];
      final notes = <String>['verified'];

      final program = PointProgram(
        id: _id('point_program_one'),
        name: 'Point Program',
        issuerName: 'Issuer',
        unitName: 'point',
        valueDefinition: const FixedPointValueDefinition(Rational.one),
        expiration: const NoPointExpiration(),
        status: CatalogItemStatus.active,
        sourceIds: sourceIds,
        lastVerifiedAt: _date('2026-09-20'),
        notes: notes,
      );

      sourceIds.add(_id('source_two'));
      notes.add('changed');

      expect(program.id, _id('point_program_one'));
      expect(program.valueDefinition, isA<FixedPointValueDefinition>());
      expect(program.expiration, isA<NoPointExpiration>());
      expect(program.sourceIds, <StableId>[_id('source_one')]);
      expect(program.notes, <String>['verified']);

      expect(
        () => program.sourceIds.add(_id('source_three')),
        throwsUnsupportedError,
      );
      expect(
        () => program.notes.add('new'),
        throwsUnsupportedError,
      );
    });

    test('accepts variable, unset, fixed-date, and unknown variants', () {
      final variable = _program(
        valueDefinition: const VariablePointValueDefinition(),
        expiration: FixedDatePointExpiration(_date('2027-01-01')),
      );
      final unset = _program(
        valueDefinition: const UnsetPointValueDefinition(),
        expiration: const UnknownPointExpiration(),
      );
      final duration = _program(
        valueDefinition: const FixedPointValueDefinition(Rational.one),
        expiration: DurationMonthsPointExpiration(24),
      );

      expect(variable.valueDefinition, isA<VariablePointValueDefinition>());
      expect(variable.expiration, isA<FixedDatePointExpiration>());
      expect(unset.valueDefinition, isA<UnsetPointValueDefinition>());
      expect(unset.expiration, isA<UnknownPointExpiration>());
      expect(duration.expiration, isA<DurationMonthsPointExpiration>());
    });

    test('rejects blank required text', () {
      expect(
        () => _program(name: ''),
        throwsArgumentError,
      );
      expect(
        () => _program(issuerName: ''),
        throwsArgumentError,
      );
      expect(
        () => _program(unitName: ''),
        throwsArgumentError,
      );
    });

    test('rejects duplicate source IDs and notes', () {
      final sourceId = _id('source_one');

      expect(
        () => _program(
          sourceIds: <StableId>[sourceId, sourceId],
        ),
        throwsArgumentError,
      );

      expect(
        () => _program(
          notes: const <String>['note', 'note'],
        ),
        throwsArgumentError,
      );
    });
  });
}

PointProgram _program({
  String name = 'Point Program',
  String issuerName = 'Issuer',
  String unitName = 'point',
  PointValueDefinition valueDefinition =
      const FixedPointValueDefinition(Rational.one),
  PointExpiration expiration = const NoPointExpiration(),
  Iterable<StableId> sourceIds = const <StableId>[],
  Iterable<String> notes = const <String>[],
}) {
  return PointProgram(
    id: _id('point_program_one'),
    name: name,
    issuerName: issuerName,
    unitName: unitName,
    valueDefinition: valueDefinition,
    expiration: expiration,
    status: CatalogItemStatus.active,
    sourceIds: sourceIds,
    lastVerifiedAt: _date('2026-09-20'),
    notes: notes,
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

Rational _rational(int numerator, int denominator) {
  final result = Rational.create(numerator, denominator);
  expect(result, isA<AppSuccess<Rational>>());
  return (result as AppSuccess<Rational>).value;
}

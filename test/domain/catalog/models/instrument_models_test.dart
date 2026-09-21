import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/validity_period.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/instrument_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentInstrument', () {
    test('stores typed fields and defensively copies collections', () {
      final brandIds = <StableId>[_id('brand_one')];
      final modeIds = <StableId>[_id('mode_one')];
      final routeIds = <StableId>[_id('route_one')];
      final sourceIds = <StableId>[_id('source_one')];
      final claims = <String>['1 percent'];
      final tags = <StableId>[_id('tag_one')];
      final notes = <String>['verified'];

      final instrument = PaymentInstrument(
        id: _id('instrument_one'),
        name: 'Instrument One',
        shortName: 'One',
        instrumentType: 'creditCard',
        issuerName: 'Issuer',
        partnerInstitutionName: null,
        availableBrandIds: brandIds,
        annualFee: const MoneyYen(0),
        supportedModeIds: modeIds,
        supportedRouteIds: routeIds,
        validityPeriod: _period(),
        status: CatalogItemStatus.active,
        sourceIds: sourceIds,
        lastVerifiedAt: _date('2026-09-20'),
        displayClaims: claims,
        tags: tags,
        notes: notes,
      );

      brandIds.add(_id('brand_two'));
      modeIds.add(_id('mode_two'));
      routeIds.add(_id('route_two'));
      sourceIds.add(_id('source_two'));
      claims.add('changed');
      tags.add(_id('tag_two'));
      notes.add('changed');

      expect(instrument.id, _id('instrument_one'));
      expect(instrument.availableBrandIds, <StableId>[_id('brand_one')]);
      expect(instrument.supportedModeIds, <StableId>[_id('mode_one')]);
      expect(instrument.supportedRouteIds, <StableId>[_id('route_one')]);
      expect(instrument.sourceIds, <StableId>[_id('source_one')]);
      expect(instrument.displayClaims, <String>['1 percent']);
      expect(instrument.tags, <StableId>[_id('tag_one')]);
      expect(instrument.notes, <String>['verified']);

      expect(
        () => instrument.availableBrandIds.add(_id('brand_three')),
        throwsUnsupportedError,
      );
      expect(
        () => instrument.notes.add('new note'),
        throwsUnsupportedError,
      );
    });

    test('rejects negative annual fee and blank required text', () {
      expect(
        () => _instrument(annualFee: const MoneyYen(-1)),
        throwsArgumentError,
      );
      expect(
        () => _instrument(name: ''),
        throwsArgumentError,
      );
      expect(
        () => _instrument(partnerInstitutionName: ''),
        throwsArgumentError,
      );
    });

    test('rejects duplicate set-like values', () {
      final duplicate = _id('brand_one');

      expect(
        () => _instrument(
          availableBrandIds: <StableId>[duplicate, duplicate],
        ),
        throwsArgumentError,
      );
    });
  });

  group('PaymentMode', () {
    test('stores schema enum and freezes route IDs', () {
      final routeIds = <StableId>[_id('route_one')];

      final mode = PaymentMode(
        id: _id('mode_one'),
        instrumentId: _id('instrument_one'),
        name: 'Credit',
        modeType: PaymentModeType.credit,
        supportedRouteIds: routeIds,
        validityPeriod: _period(),
        status: CatalogItemStatus.active,
        sourceIds: <StableId>[_id('source_one')],
        notes: const <String>[],
      );

      routeIds.add(_id('route_two'));

      expect(mode.modeType.value, 'credit');
      expect(mode.supportedRouteIds, <StableId>[_id('route_one')]);
      expect(
        () => mode.supportedRouteIds.add(_id('route_three')),
        throwsUnsupportedError,
      );
    });

    test('rejects duplicate route IDs', () {
      final routeId = _id('route_one');

      expect(
        () => PaymentMode(
          id: _id('mode_one'),
          instrumentId: _id('instrument_one'),
          name: 'Credit',
          modeType: PaymentModeType.credit,
          supportedRouteIds: <StableId>[routeId, routeId],
          validityPeriod: _period(),
          status: CatalogItemStatus.active,
          sourceIds: const <StableId>[],
          notes: const <String>[],
        ),
        throwsArgumentError,
      );
    });
  });

  group('PaymentRoute', () {
    test('supports nullable device requirement and freezes collections', () {
      final instrumentIds = <StableId>[_id('instrument_one')];

      final route = PaymentRoute(
        id: _id('route_one'),
        name: 'Contactless',
        routeType: 'contactless',
        brandIds: <StableId>[_id('brand_one')],
        deviceRequirement: null,
        supportedInstrumentIds: instrumentIds,
        validityPeriod: _period(),
        status: CatalogItemStatus.active,
        sourceIds: <StableId>[_id('source_one')],
        notes: const <String>[],
      );

      instrumentIds.add(_id('instrument_two'));

      expect(route.deviceRequirement, isNull);
      expect(
        route.supportedInstrumentIds,
        <StableId>[_id('instrument_one')],
      );
    });

    test('rejects an empty non-null device requirement', () {
      expect(
        () => PaymentRoute(
          id: _id('route_one'),
          name: 'Contactless',
          routeType: 'contactless',
          brandIds: const <StableId>[],
          deviceRequirement: '',
          supportedInstrumentIds: const <StableId>[],
          validityPeriod: _period(),
          status: CatalogItemStatus.active,
          sourceIds: const <StableId>[],
          notes: const <String>[],
        ),
        throwsArgumentError,
      );
    });
  });

  group('FundingRelation', () {
    test('stores typed endpoints and freezes source references', () {
      final sourceIds = <StableId>[_id('source_one')];

      final relation = FundingRelation(
        id: _id('funding_one'),
        sourceInstrumentId: _id('instrument_one'),
        destinationInstrumentId: _id('instrument_two'),
        relationType: 'charge',
        validityPeriod: _period(),
        status: CatalogItemStatus.active,
        sourceIds: sourceIds,
        notes: const <String>[],
      );

      sourceIds.add(_id('source_two'));

      expect(relation.sourceInstrumentId, _id('instrument_one'));
      expect(relation.destinationInstrumentId, _id('instrument_two'));
      expect(relation.sourceIds, <StableId>[_id('source_one')]);
    });

    test('rejects an empty relation type', () {
      expect(
        () => FundingRelation(
          id: _id('funding_one'),
          sourceInstrumentId: _id('instrument_one'),
          destinationInstrumentId: _id('instrument_two'),
          relationType: '',
          validityPeriod: _period(),
          status: CatalogItemStatus.active,
          sourceIds: const <StableId>[],
          notes: const <String>[],
        ),
        throwsArgumentError,
      );
    });
  });
}

PaymentInstrument _instrument({
  String name = 'Instrument One',
  String? partnerInstitutionName,
  MoneyYen annualFee = const MoneyYen(0),
  Iterable<StableId>? availableBrandIds,
}) {
  return PaymentInstrument(
    id: _id('instrument_one'),
    name: name,
    shortName: 'One',
    instrumentType: 'creditCard',
    issuerName: 'Issuer',
    partnerInstitutionName: partnerInstitutionName,
    availableBrandIds: availableBrandIds ?? <StableId>[_id('brand_one')],
    annualFee: annualFee,
    supportedModeIds: <StableId>[_id('mode_one')],
    supportedRouteIds: <StableId>[_id('route_one')],
    validityPeriod: _period(),
    status: CatalogItemStatus.active,
    sourceIds: <StableId>[_id('source_one')],
    lastVerifiedAt: _date('2026-09-20'),
    displayClaims: const <String>[],
    tags: const <StableId>[],
    notes: const <String>[],
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

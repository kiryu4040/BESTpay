import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/source_migration_models.dart';
import 'package:bestpay/domain/catalog/models/typed_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TypedCatalog', () {
    test('exposes all twelve typed catalog indexes', () {
      final catalog = _catalog();

      expect(catalog.paymentInstruments, isEmpty);
      expect(catalog.paymentRoutes, isEmpty);
      expect(catalog.paymentModes, isEmpty);
      expect(catalog.fundingRelations, isEmpty);
      expect(catalog.merchants, isEmpty);
      expect(catalog.merchantGroups, isEmpty);
      expect(catalog.merchantCategories, isEmpty);
      expect(catalog.pointPrograms, isEmpty);
      expect(catalog.conditionDefinitions, isEmpty);
      expect(catalog.rewardRules, isEmpty);
      expect(catalog.sources, isEmpty);
      expect(catalog.idMigrations, isEmpty);
    });

    test('indexes entities by StableId', () {
      final source = _source('source_one');
      final catalog = _catalog(sources: <CatalogSource>[source]);

      expect(catalog.sources.length, 1);
      expect(catalog.sources[_id('source_one')], same(source));
    });

    test('defensively copies input collections', () {
      final source = _source('source_one');
      final sources = <CatalogSource>[source];

      final catalog = _catalog(sources: sources);
      sources.add(_source('source_two'));

      expect(catalog.sources.keys, <StableId>[_id('source_one')]);
      expect(catalog.sources.containsKey(_id('source_two')), isFalse);
    });

    test('preserves validated input order in each index', () {
      final first = _source('source_one');
      final second = _source('source_two');

      final catalog = _catalog(
        sources: <CatalogSource>[first, second],
      );

      expect(
        catalog.sources.keys.toList(),
        <StableId>[_id('source_one'), _id('source_two')],
      );
    });

    test('exposes unmodifiable maps', () {
      final source = _source('source_one');
      final catalog = _catalog(sources: <CatalogSource>[source]);

      expect(
        () => catalog.sources[_id('source_two')] = _source('source_two'),
        throwsUnsupportedError,
      );

      expect(
        () => catalog.paymentInstruments.clear(),
        throwsUnsupportedError,
      );
    });

    test('rejects duplicate IDs atomically', () {
      final first = _source('source_same');
      final second = _source('source_same');

      expect(
        () => _catalog(
          sources: <CatalogSource>[first, second],
        ),
        throwsArgumentError,
      );
    });

    test('does not reject the same ID across different catalog types', () {
      final source = _source('shared_entity');

      final migration = IdMigration(
        id: _id('shared_entity'),
        entityType: 'merchant',
        migrationType: IdMigrationType.rename,
        fromIds: <StableId>[_id('merchant_old')],
        toIds: <StableId>[_id('merchant_new')],
        evidenceSourceIds: <StableId>[_id('source_evidence')],
        needsReview: false,
        effectiveFrom: _date('2026-09-20'),
        notes: const <String>[],
      );

      final catalog = _catalog(
        sources: <CatalogSource>[source],
        idMigrations: <IdMigration>[migration],
      );

      expect(catalog.sources.containsKey(_id('shared_entity')), isTrue);
      expect(catalog.idMigrations.containsKey(_id('shared_entity')), isTrue);
    });
  });
}

TypedCatalog _catalog({
  Iterable<CatalogSource> sources = const <CatalogSource>[],
  Iterable<IdMigration> idMigrations = const <IdMigration>[],
}) {
  return TypedCatalog(
    paymentInstruments: const [],
    paymentRoutes: const [],
    paymentModes: const [],
    fundingRelations: const [],
    merchants: const [],
    merchantGroups: const [],
    merchantCategories: const [],
    pointPrograms: const [],
    conditionDefinitions: const [],
    rewardRules: const [],
    sources: sources,
    idMigrations: idMigrations,
  );
}

CatalogSource _source(String id) {
  return CatalogSource(
    id: _id(id),
    title: 'Official Terms',
    url: Uri.parse('https://example.com/terms'),
    publisher: 'Example Publisher',
    sourceType: CatalogSourceType.officialTerms,
    publishedAt: null,
    lastVerifiedAt: _date('2026-09-20'),
    accessStatus: CatalogSourceAccessStatus.accessible,
    reliability: CatalogSourceReliability.primary,
    relevantSections: const <String>[],
    summary: '',
    contentHash: null,
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

import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/source_migration_models.dart';
import 'package:flutter_test/flutter_test.dart';

const String _validContentHash = '0123456789abcdef'
    '0123456789abcdef'
    '0123456789abcdef'
    '0123456789abcdef';

void main() {
  group('source and migration schema enums', () {
    test('source types use stable schema values', () {
      expect(
        CatalogSourceType.values.map((value) => value.value),
        <String>[
          'officialTerms',
          'officialFaq',
          'officialProductPage',
          'officialCampaignPage',
          'officialNewsRelease',
          'officialAppNotice',
          'secondaryArticle',
          'userReport',
        ],
      );
    });

    test('source access states use stable schema values', () {
      expect(
        CatalogSourceAccessStatus.values.map((value) => value.value),
        <String>[
          'accessible',
          'changed',
          'unavailable',
          'archived',
        ],
      );
    });

    test('source reliability values use stable schema values', () {
      expect(
        CatalogSourceReliability.values.map((value) => value.value),
        <String>[
          'primary',
          'secondary',
          'userReported',
          'unverified',
        ],
      );
    });

    test('migration types use stable schema values', () {
      expect(
        IdMigrationType.values.map((value) => value.value),
        <String>[
          'rename',
          'merge',
          'split',
          'remove',
        ],
      );
    });
  });

  group('CatalogSource', () {
    test('stores typed values and supports nullable fields', () {
      final source = _source(
        publishedAt: null,
        contentHash: null,
      );

      expect(source.id, _id('source_one'));
      expect(source.url, Uri.parse('https://example.com/terms'));
      expect(source.sourceType, CatalogSourceType.officialTerms);
      expect(source.publishedAt, isNull);
      expect(source.contentHash, isNull);
      expect(source.summary, '');
    });

    test('defensively copies and freezes text collections', () {
      final sections = <String>['Section 1'];
      final notes = <String>['Verified'];

      final source = _source(
        relevantSections: sections,
        notes: notes,
      );

      sections.add('Section 2');
      notes.add('Changed');

      expect(source.relevantSections, <String>['Section 1']);
      expect(source.notes, <String>['Verified']);

      expect(
        () => source.relevantSections.add('Section 3'),
        throwsUnsupportedError,
      );
      expect(
        () => source.notes.add('Other'),
        throwsUnsupportedError,
      );
    });

    test('accepts a valid lowercase SHA-256 content hash', () {
      final source = _source(contentHash: _validContentHash);

      expect(source.contentHash, _validContentHash);
    });

    test('rejects blank required text and a relative URI', () {
      expect(
        () => _source(title: ''),
        throwsArgumentError,
      );
      expect(
        () => _source(publisher: ''),
        throwsArgumentError,
      );
      expect(
        () => _source(url: Uri.parse('/relative/path')),
        throwsArgumentError,
      );
    });

    test('rejects malformed content hashes', () {
      expect(
        () => _source(contentHash: 'abc'),
        throwsArgumentError,
      );

      expect(
        () => _source(
          contentHash: 'ABCDEF0123456789'
              'abcdef0123456789'
              'abcdef0123456789'
              'abcdef0123456789',
        ),
        throwsArgumentError,
      );
    });

    test('rejects blank and duplicate collection values', () {
      expect(
        () => _source(relevantSections: <String>['']),
        throwsArgumentError,
      );
      expect(
        () => _source(notes: <String>['same', 'same']),
        throwsArgumentError,
      );
    });
  });

  group('IdMigration valid shapes', () {
    test('accepts rename with one source and one destination', () {
      final migration = _migration(
        migrationType: IdMigrationType.rename,
        fromIds: <StableId>[_id('merchant_old')],
        toIds: <StableId>[_id('merchant_new')],
        needsReview: false,
      );

      expect(migration.fromIds.length, 1);
      expect(migration.toIds.length, 1);
    });

    test('accepts merge with multiple sources and one destination', () {
      final migration = _migration(
        migrationType: IdMigrationType.merge,
        fromIds: <StableId>[
          _id('merchant_old_one'),
          _id('merchant_old_two'),
        ],
        toIds: <StableId>[_id('merchant_new')],
        needsReview: false,
      );

      expect(migration.fromIds.length, 2);
      expect(migration.toIds.length, 1);
    });

    test('accepts reviewed split with one source and multiple destinations',
        () {
      final migration = _migration(
        migrationType: IdMigrationType.split,
        fromIds: <StableId>[_id('merchant_old')],
        toIds: <StableId>[
          _id('merchant_new_one'),
          _id('merchant_new_two'),
        ],
        needsReview: true,
      );

      expect(migration.needsReview, isTrue);
      expect(migration.toIds.length, 2);
    });

    test('accepts reviewed removal with no destination', () {
      final migration = _migration(
        migrationType: IdMigrationType.remove,
        fromIds: <StableId>[_id('merchant_old')],
        toIds: const <StableId>[],
        needsReview: true,
      );

      expect(migration.needsReview, isTrue);
      expect(migration.toIds, isEmpty);
    });
  });

  group('IdMigration validation', () {
    test('rejects invalid rename cardinality', () {
      expect(
        () => _migration(
          migrationType: IdMigrationType.rename,
          fromIds: <StableId>[
            _id('merchant_old_one'),
            _id('merchant_old_two'),
          ],
          toIds: <StableId>[_id('merchant_new')],
          needsReview: false,
        ),
        throwsArgumentError,
      );

      expect(
        () => _migration(
          migrationType: IdMigrationType.rename,
          fromIds: <StableId>[_id('merchant_old')],
          toIds: const <StableId>[],
          needsReview: false,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid merge cardinality', () {
      expect(
        () => _migration(
          migrationType: IdMigrationType.merge,
          fromIds: <StableId>[_id('merchant_old')],
          toIds: <StableId>[_id('merchant_new')],
          needsReview: false,
        ),
        throwsArgumentError,
      );

      expect(
        () => _migration(
          migrationType: IdMigrationType.merge,
          fromIds: <StableId>[
            _id('merchant_old_one'),
            _id('merchant_old_two'),
          ],
          toIds: <StableId>[
            _id('merchant_new_one'),
            _id('merchant_new_two'),
          ],
          needsReview: false,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid split cardinality or review state', () {
      expect(
        () => _migration(
          migrationType: IdMigrationType.split,
          fromIds: <StableId>[
            _id('merchant_old_one'),
            _id('merchant_old_two'),
          ],
          toIds: <StableId>[
            _id('merchant_new_one'),
            _id('merchant_new_two'),
          ],
          needsReview: true,
        ),
        throwsArgumentError,
      );

      expect(
        () => _migration(
          migrationType: IdMigrationType.split,
          fromIds: <StableId>[_id('merchant_old')],
          toIds: <StableId>[
            _id('merchant_new_one'),
            _id('merchant_new_two'),
          ],
          needsReview: false,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid removal destination or review state', () {
      expect(
        () => _migration(
          migrationType: IdMigrationType.remove,
          fromIds: <StableId>[_id('merchant_old')],
          toIds: <StableId>[_id('merchant_new')],
          needsReview: true,
        ),
        throwsArgumentError,
      );

      expect(
        () => _migration(
          migrationType: IdMigrationType.remove,
          fromIds: <StableId>[_id('merchant_old')],
          toIds: const <StableId>[],
          needsReview: false,
        ),
        throwsArgumentError,
      );
    });

    test('rejects blank entity type and duplicate IDs', () {
      expect(
        () => _migration(
          entityType: '',
          migrationType: IdMigrationType.rename,
          fromIds: <StableId>[_id('merchant_old')],
          toIds: <StableId>[_id('merchant_new')],
          needsReview: false,
        ),
        throwsArgumentError,
      );

      final duplicate = _id('merchant_old');

      expect(
        () => _migration(
          migrationType: IdMigrationType.merge,
          fromIds: <StableId>[duplicate, duplicate],
          toIds: <StableId>[_id('merchant_new')],
          needsReview: false,
        ),
        throwsArgumentError,
      );
    });

    test('defensively copies and freezes all collections', () {
      final fromIds = <StableId>[
        _id('merchant_old_one'),
        _id('merchant_old_two'),
      ];
      final toIds = <StableId>[_id('merchant_new')];
      final sourceIds = <StableId>[_id('source_one')];
      final notes = <String>['Confirmed'];

      final migration = _migration(
        migrationType: IdMigrationType.merge,
        fromIds: fromIds,
        toIds: toIds,
        evidenceSourceIds: sourceIds,
        notes: notes,
        needsReview: false,
      );

      fromIds.add(_id('merchant_old_three'));
      toIds.add(_id('merchant_other'));
      sourceIds.add(_id('source_two'));
      notes.add('Changed');

      expect(migration.fromIds.length, 2);
      expect(migration.toIds, <StableId>[_id('merchant_new')]);
      expect(migration.evidenceSourceIds, <StableId>[_id('source_one')]);
      expect(migration.notes, <String>['Confirmed']);

      expect(
        () => migration.fromIds.add(_id('merchant_old_four')),
        throwsUnsupportedError,
      );
      expect(
        () => migration.evidenceSourceIds.add(_id('source_three')),
        throwsUnsupportedError,
      );
      expect(
        () => migration.notes.add('Other'),
        throwsUnsupportedError,
      );
    });
  });
}

CatalogSource _source({
  String title = 'Official Terms',
  Uri? url,
  String publisher = 'Example Publisher',
  CalculationDate? publishedAt,
  String? contentHash = _validContentHash,
  Iterable<String> relevantSections = const <String>[],
  Iterable<String> notes = const <String>[],
}) {
  return CatalogSource(
    id: _id('source_one'),
    title: title,
    url: url ?? Uri.parse('https://example.com/terms'),
    publisher: publisher,
    sourceType: CatalogSourceType.officialTerms,
    publishedAt: publishedAt,
    lastVerifiedAt: _date('2026-09-20'),
    accessStatus: CatalogSourceAccessStatus.accessible,
    reliability: CatalogSourceReliability.primary,
    relevantSections: relevantSections,
    summary: '',
    contentHash: contentHash,
    notes: notes,
  );
}

IdMigration _migration({
  String entityType = 'merchant',
  required IdMigrationType migrationType,
  required Iterable<StableId> fromIds,
  required Iterable<StableId> toIds,
  Iterable<StableId> evidenceSourceIds = const <StableId>[],
  required bool needsReview,
  Iterable<String> notes = const <String>[],
}) {
  return IdMigration(
    id: _id('migration_one'),
    entityType: entityType,
    migrationType: migrationType,
    fromIds: fromIds,
    toIds: toIds,
    evidenceSourceIds: evidenceSourceIds,
    needsReview: needsReview,
    effectiveFrom: _date('2026-09-20'),
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

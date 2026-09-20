import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/catalog_version.dart';
import 'package:bestpay/domain/catalog/catalog_diagnostic.dart';
import 'package:bestpay/domain/catalog/catalog_diagnostic_code.dart';
import 'package:bestpay/domain/catalog/catalog_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CatalogVersion validVersion() {
    final result = CatalogVersion.create('2026.09.19.1');
    expect(result, isA<AppSuccess<CatalogVersion>>());
    return (result as AppSuccess<CatalogVersion>).value;
  }

  test('creates an immutable publishable snapshot', () {
    final items = <Object?>[
      <String, Object?>{'id': 'instrument_a'},
    ];

    final documents = <String, Object?>{
      'payment_instruments.json': <String, Object?>{
        'items': items,
      },
    };

    final indexes = <String, Object?>{
      'itemsById': <String, Object?>{
        'instrument_a': <String, Object?>{'active': true},
      },
    };

    final snapshot = CatalogSnapshot(
      schemaVersion: '1.0.0',
      catalogVersion: validVersion(),
      generatedAt: DateTime.utc(2026, 9, 19),
      documents: documents,
      indexes: indexes,
      diagnostics: <CatalogDiagnostic>[
        CatalogDiagnostic(
          code: CatalogDiagnosticCode.parse('CAT-W001'),
          message: 'Review recommended.',
        ),
      ],
    );

    items.add(<String, Object?>{'id': 'instrument_b'});
    documents['other.json'] = <String, Object?>{};
    indexes['other'] = true;

    final document =
        snapshot.documents['payment_instruments.json']! as Map<String, Object?>;
    final frozenItems = document['items']! as List<Object?>;

    expect(frozenItems, hasLength(1));
    expect(snapshot.documents.containsKey('other.json'), isFalse);
    expect(snapshot.indexes.containsKey('other'), isFalse);
    expect(snapshot.diagnostics, hasLength(1));

    expect(
      () => frozenItems.add(<String, Object?>{}),
      throwsUnsupportedError,
    );
    expect(
      () => snapshot.documents['other.json'] = <String, Object?>{},
      throwsUnsupportedError,
    );
  });

  test('rejects fatal and error diagnostics', () {
    for (final code in <String>['CAT-F001', 'CAT-E001']) {
      expect(
        () => CatalogSnapshot(
          schemaVersion: '1.0.0',
          catalogVersion: validVersion(),
          generatedAt: DateTime.utc(2026, 9, 19),
          documents: const <String, Object?>{},
          diagnostics: <CatalogDiagnostic>[
            CatalogDiagnostic(
              code: CatalogDiagnosticCode.parse(code),
              message: 'Publication must be blocked.',
            ),
          ],
        ),
        throwsArgumentError,
      );
    }
  });

  test('allows warning and info diagnostics', () {
    final snapshot = CatalogSnapshot(
      schemaVersion: '1.0.0',
      catalogVersion: validVersion(),
      generatedAt: DateTime.utc(2026, 9, 19),
      documents: const <String, Object?>{},
      diagnostics: <CatalogDiagnostic>[
        CatalogDiagnostic(
          code: CatalogDiagnosticCode.parse('CAT-W001'),
          message: 'Warning.',
        ),
        CatalogDiagnostic(
          code: CatalogDiagnosticCode.parse('CAT-I001'),
          message: 'Information.',
        ),
      ],
    );

    expect(snapshot.diagnostics, hasLength(2));
  });

  test('rejects blank schema versions and non-JSON values', () {
    expect(
      () => CatalogSnapshot(
        schemaVersion: ' ',
        catalogVersion: validVersion(),
        generatedAt: DateTime.utc(2026, 9, 19),
        documents: const <String, Object?>{},
      ),
      throwsArgumentError,
    );

    expect(
      () => CatalogSnapshot(
        schemaVersion: '1.0.0',
        catalogVersion: validVersion(),
        generatedAt: DateTime.utc(2026, 9, 19),
        documents: <String, Object?>{
          'invalid': DateTime.utc(2026, 9, 19),
        },
      ),
      throwsArgumentError,
    );
  });
}

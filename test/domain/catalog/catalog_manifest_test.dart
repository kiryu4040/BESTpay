import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/catalog_version.dart';
import 'package:bestpay/domain/catalog/catalog_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CatalogVersion version() {
    final result = CatalogVersion.create('2026.09.19.1');
    return (result as AppSuccess<CatalogVersion>).value;
  }

  List<CatalogManifestItem> validItems() {
    return CatalogManifest.expectedSchemaIds.entries
        .map(
          (entry) => CatalogManifestItem(
            fileName: entry.key,
            schemaId: entry.value,
            contentHash: List<String>.filled(64, '0').join(),
            isRequired: true,
          ),
        )
        .toList();
  }

  CatalogManifest validManifest() {
    return CatalogManifest(
      schemaVersion: '1.0.0',
      catalogVersion: version(),
      generatedAt: DateTime.utc(2026, 9, 19),
      items: validItems(),
    );
  }

  test('accepts the complete twelve-file manifest', () {
    final manifest = validManifest();

    expect(manifest.items, hasLength(12));
    expect(manifest.itemsByFileName, hasLength(12));
    expect(
      manifest.itemsByFileName.keys,
      containsAll(CatalogManifest.expectedSchemaIds.keys),
    );
  });

  test('rejects an unsupported schema version', () {
    expect(
      () => CatalogManifest(
        schemaVersion: '2.0.0',
        catalogVersion: version(),
        generatedAt: DateTime.utc(2026, 9, 19),
        items: validItems(),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a missing required file', () {
    final items = validItems()..removeLast();

    expect(
      () => CatalogManifest(
        schemaVersion: '1.0.0',
        catalogVersion: version(),
        generatedAt: DateTime.utc(2026, 9, 19),
        items: items,
      ),
      throwsArgumentError,
    );
  });

  test('rejects duplicate file names', () {
    final items = validItems();
    items[1] = items.first;

    expect(
      () => CatalogManifest(
        schemaVersion: '1.0.0',
        catalogVersion: version(),
        generatedAt: DateTime.utc(2026, 9, 19),
        items: items,
      ),
      throwsArgumentError,
    );
  });

  test('rejects mismatched file name and schema ID', () {
    expect(
      () => CatalogManifestItem(
        fileName: 'payment_instruments.json',
        schemaId: 'urn:bestpay:schema:payment-route:1.0.0',
        contentHash: List<String>.filled(64, '0').join(),
        isRequired: true,
      ),
      throwsArgumentError,
    );
  });

  test('rejects malformed or uppercase hashes', () {
    for (final hash in <String>[
      'abc',
      List<String>.filled(64, 'A').join(),
    ]) {
      expect(
        () => CatalogManifestItem(
          fileName: 'payment_instruments.json',
          schemaId: 'urn:bestpay:schema:payment-instrument:1.0.0',
          contentHash: hash,
          isRequired: true,
        ),
        throwsArgumentError,
      );
    }
  });

  test('exposes immutable collections', () {
    final manifest = validManifest();

    expect(
      () => manifest.items.add(manifest.items.first),
      throwsUnsupportedError,
    );
    expect(
      () => manifest.itemsByFileName.clear(),
      throwsUnsupportedError,
    );
  });
}

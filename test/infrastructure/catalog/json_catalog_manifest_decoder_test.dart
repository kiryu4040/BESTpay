import 'dart:convert';

import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/domain/catalog/catalog_manifest.dart';
import 'package:bestpay/infrastructure/catalog/json_catalog_manifest_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> validJson() {
    return <String, Object?>{
      'schemaVersion': '1.0.0',
      'catalogVersion': '2026.09.19.1',
      'generatedAt': '2026-09-19T00:00:00Z',
      'items': CatalogManifest.expectedSchemaIds.entries
          .map(
            (entry) => <String, Object?>{
              'fileName': entry.key,
              'schemaId': entry.value,
              'contentHash': List<String>.filled(64, '0').join(),
              'required': true,
            },
          )
          .toList(),
    };
  }

  const decoder = JsonCatalogManifestDecoder();

  test('decodes a complete manifest', () {
    final result = decoder.decode(
      utf8.encode(jsonEncode(validJson())),
    );

    expect(result, isA<AppSuccess<CatalogManifest>>());

    final manifest = (result as AppSuccess<CatalogManifest>).value;

    expect(manifest.schemaVersion, '1.0.0');
    expect(manifest.catalogVersion.value, '2026.09.19.1');
    expect(manifest.items, hasLength(12));
  });

  test('returns decode failure for malformed UTF-8 JSON', () {
    final result = decoder.decode(
      const <int>[0x7b, 0xff, 0x7d],
    );

    expect(result, isA<AppFailure<CatalogManifest>>());
    expect(
      (result as AppFailure<CatalogManifest>).error.code,
      AppErrorCode.catalogDecodeFailed,
    );
  });

  test('returns validation failure for a missing file', () {
    final json = validJson();
    final items = json['items']! as List<Object?>;
    items.removeLast();

    final result = decoder.decode(
      utf8.encode(jsonEncode(json)),
    );

    expect(result, isA<AppFailure<CatalogManifest>>());
    expect(
      (result as AppFailure<CatalogManifest>).error.code,
      AppErrorCode.catalogValidationFailed,
    );
  });

  test('returns validation failure for invalid catalog version', () {
    final json = validJson();
    json['catalogVersion'] = 'v2';

    final result = decoder.decode(
      utf8.encode(jsonEncode(json)),
    );

    expect(result, isA<AppFailure<CatalogManifest>>());
    expect(
      (result as AppFailure<CatalogManifest>).error.code,
      AppErrorCode.catalogValidationFailed,
    );
  });

  test('returns validation failure for schema mismatch', () {
    final json = validJson();
    final items = json['items']! as List<Object?>;
    final first = items.first! as Map<String, Object?>;
    first['schemaId'] = 'urn:bestpay:schema:payment-route:1.0.0';

    final result = decoder.decode(
      utf8.encode(jsonEncode(json)),
    );

    expect(result, isA<AppFailure<CatalogManifest>>());
    expect(
      (result as AppFailure<CatalogManifest>).error.code,
      AppErrorCode.catalogValidationFailed,
    );
  });
}

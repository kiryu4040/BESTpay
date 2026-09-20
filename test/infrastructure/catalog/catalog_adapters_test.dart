import 'dart:convert';

import 'package:bestpay/application/catalog/catalog_schema_validator.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/infrastructure/catalog/json_schema_catalog_validator.dart';
import 'package:bestpay/infrastructure/catalog/memory_catalog_file_source.dart';
import 'package:bestpay/infrastructure/catalog/sha256_content_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryCatalogFileSource', () {
    test('returns a defensive copy of known file bytes', () async {
      final sourceBytes = utf8.encode('{"value":"ok"}');
      final source = MemoryCatalogFileSource(
        <String, List<int>>{
          'example.json': sourceBytes,
        },
      );

      sourceBytes[0] = 0;

      final result = await source.read('example.json');

      expect(result, isA<AppSuccess>());
      final file = (result as AppSuccess).value;
      expect(utf8.decode(file.bytes), '{"value":"ok"}');
      expect(() => file.bytes.add(0), throwsUnsupportedError);
    });

    test('returns a structured failure for unknown file', () async {
      final source = MemoryCatalogFileSource(
        const <String, List<int>>{},
      );

      final result = await source.read('missing.json');

      expect(result, isA<AppFailure>());
    });
  });

  group('Sha256ContentHasher', () {
    test('matches the SHA-256 known vector for abc', () {
      const hasher = Sha256ContentHasher();

      expect(
        hasher.sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223'
        'b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('hashes original bytes rather than normalized JSON', () {
      const hasher = Sha256ContentHasher();

      expect(
        hasher.sha256Hex(utf8.encode('{"value":1}')),
        isNot(
          hasher.sha256Hex(utf8.encode('{ "value": 1 }')),
        ),
      );
    });
  });

  group('JsonSchemaCatalogValidator', () {
    const commonId = 'urn:bestpay:test:schema:stable-id:1.0.0';
    const rootId = 'urn:bestpay:test:schema:catalog-root:1.0.0';

    Map<String, Map<String, dynamic>> schemas() {
      return <String, Map<String, dynamic>>{
        commonId: <String, dynamic>{
          r'$schema': 'https://json-schema.org/draft/2020-12/schema',
          r'$id': commonId,
          'type': 'string',
          'pattern': r'^[a-z][a-z0-9_]{2,79}$',
        },
        rootId: <String, dynamic>{
          r'$schema': 'https://json-schema.org/draft/2020-12/schema',
          r'$id': rootId,
          'type': 'object',
          'additionalProperties': false,
          'required': <String>['id'],
          'properties': <String, Object?>{
            'id': <String, Object?>{
              r'$ref': commonId,
            },
          },
        },
      };
    }

    JsonSchemaCatalogValidator validator() {
      return JsonSchemaCatalogValidator(
        schemasById: schemas(),
      );
    }

    test('registers all supplied schema IDs', () {
      expect(validator().schemaIds, <String>{commonId, rootId});
    });

    test('resolves fragment-free URN reference', () async {
      final result = await validator().validate(
        schemaId: rootId,
        document: const <String, Object?>{
          'id': 'item_001',
        },
      );

      expect(
        result,
        isA<AppSuccess<CatalogSchemaValidationResult>>(),
      );
      expect(
        (result as AppSuccess<CatalogSchemaValidationResult>).value.isValid,
        isTrue,
      );
    });

    test('returns technical schema issues for invalid data', () async {
      final result = await validator().validate(
        schemaId: rootId,
        document: const <String, Object?>{
          'id': 'INVALID',
        },
      );

      expect(
        result,
        isA<AppSuccess<CatalogSchemaValidationResult>>(),
      );

      final validation =
          (result as AppSuccess<CatalogSchemaValidationResult>).value;

      expect(validation.isValid, isFalse);
      expect(validation.errors, isNotEmpty);
    });

    test('returns AppFailure for an unknown schema', () async {
      final result = await validator().validate(
        schemaId: 'urn:bestpay:test:schema:unknown:1.0.0',
        document: const <String, Object?>{},
      );

      expect(
        result,
        isA<AppFailure<CatalogSchemaValidationResult>>(),
      );

      expect(
        (result as AppFailure<CatalogSchemaValidationResult>).error.code,
        AppErrorCode.catalogValidationFailed,
      );
    });

    test('copies source schema maps before compilation', () async {
      final sourceSchemas = schemas();
      final schemaValidator = JsonSchemaCatalogValidator(
        schemasById: sourceSchemas,
      );

      sourceSchemas.clear();

      final result = await schemaValidator.validate(
        schemaId: rootId,
        document: const <String, Object?>{
          'id': 'item_001',
        },
      );

      expect(
        result,
        isA<AppSuccess<CatalogSchemaValidationResult>>(),
      );
      expect(schemaValidator.schemaIds, hasLength(2));
    });

    test('requires registry keys to match schema IDs', () {
      expect(
        () => JsonSchemaCatalogValidator(
          schemasById: <String, Map<String, dynamic>>{
            'urn:bestpay:test:schema:wrong:1.0.0': <String, dynamic>{
              r'$schema': 'https://json-schema.org/draft/2020-12/schema',
              r'$id': commonId,
              'type': 'string',
            },
          },
        ),
        throwsArgumentError,
      );
    });
  });
}

import 'dart:convert';

import 'package:bestpay/application/catalog/catalog_load_result.dart';
import 'package:bestpay/application/catalog/catalog_schema_validator.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/domain/catalog/catalog_manifest.dart';
import 'package:bestpay/infrastructure/catalog/json_catalog_loader.dart';
import 'package:bestpay/infrastructure/catalog/memory_catalog_file_source.dart';
import 'package:bestpay/infrastructure/catalog/sha256_content_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hasher = Sha256ContentHasher();

  Map<String, List<int>> buildFiles({
    String? missingFile,
    String? malformedFile,
    String? mismatchedVersionFile,
    String? unsupportedSchemaFile,
    bool duplicateId = false,
  }) {
    final files = <String, List<int>>{};
    var itemNumber = 0;

    for (final entry in CatalogManifest.expectedSchemaIds.entries) {
      final fileName = entry.key;
      itemNumber++;

      final id = duplicateId && itemNumber == 2
          ? 'item_001'
          : 'item_${itemNumber.toString().padLeft(3, '0')}';

      if (fileName == malformedFile) {
        files[fileName] = utf8.encode('{invalid');
        continue;
      }

      files[fileName] = utf8.encode(
        jsonEncode(
          <String, Object?>{
            'schemaVersion':
                fileName == unsupportedSchemaFile ? '2.0.0' : '1.0.0',
            'catalogVersion': fileName == mismatchedVersionFile
                ? '2026.09.19.2'
                : '2026.09.19.1',
            'generatedAt': '2026-09-19T00:00:00Z',
            'items': <Object?>[
              <String, Object?>{'id': id},
            ],
          },
        ),
      );
    }

    final manifestItems =
        CatalogManifest.expectedSchemaIds.entries.map((entry) {
      final bytes = files[entry.key]!;
      return <String, Object?>{
        'fileName': entry.key,
        'schemaId': entry.value,
        'contentHash': hasher.sha256Hex(bytes),
        'required': true,
      };
    }).toList();

    files[JsonCatalogLoader.manifestFileName] = utf8.encode(
      jsonEncode(
        <String, Object?>{
          'schemaVersion': '1.0.0',
          'catalogVersion': '2026.09.19.1',
          'generatedAt': '2026-09-19T00:00:00Z',
          'items': manifestItems,
        },
      ),
    );

    if (missingFile != null) {
      files.remove(missingFile);
    }

    return files;
  }

  JsonCatalogLoader loader(
    Map<String, List<int>> files, {
    CatalogSchemaValidator schemaValidator = const _AcceptingSchemaValidator(),
  }) {
    return JsonCatalogLoader(
      fileSource: MemoryCatalogFileSource(files),
      schemaValidator: schemaValidator,
      contentHasher: hasher,
    );
  }

  test('publishes snapshot after all twelve files pass', () async {
    final result = await loader(buildFiles()).load();

    expect(result, isA<CatalogLoadSuccess>());

    final snapshot = (result as CatalogLoadSuccess).snapshot;
    expect(snapshot.documents, hasLength(12));

    final index = snapshot.indexes['itemsById']! as Map<String, Object?>;
    expect(index, hasLength(12));
  });

  test('reports CAT-F003 when required file is missing', () async {
    final result = await loader(
      buildFiles(missingFile: 'payment_modes.json'),
    ).load();

    expect(result, isA<CatalogLoadFailure>());
    expect(
      result.diagnostics.map((item) => item.code.value),
      contains('CAT-F003'),
    );
  });

  test('reports CAT-F004 when original bytes do not match hash', () async {
    final files = buildFiles();
    files['payment_modes.json'] = utf8.encode(
      '{"schemaVersion":"1.0.0"}',
    );

    final result = await loader(files).load();

    expect(result, isA<CatalogLoadFailure>());
    expect(
      result.diagnostics.map((item) => item.code.value),
      contains('CAT-F004'),
    );
  });

  test('returns AppError for malformed catalog JSON', () async {
    final files = buildFiles(
      malformedFile: 'payment_modes.json',
    );

    final result = await loader(files).load();

    expect(result, isA<CatalogLoadFailure>());
    expect(result.error, isNotNull);
    expect(result.error!.code, AppErrorCode.catalogDecodeFailed);
  });

  test('reports CAT-F001 for unsupported schemaVersion', () async {
    final result = await loader(
      buildFiles(
        unsupportedSchemaFile: 'payment_modes.json',
      ),
    ).load();

    expect(result, isA<CatalogLoadFailure>());
    expect(
      result.diagnostics.map((item) => item.code.value),
      contains('CAT-F001'),
    );
  });

  test('reports CAT-E003 for mismatched CatalogVersion', () async {
    final result = await loader(
      buildFiles(
        mismatchedVersionFile: 'payment_modes.json',
      ),
    ).load();

    expect(result, isA<CatalogLoadFailure>());
    expect(
      result.diagnostics.map((item) => item.code.value),
      contains('CAT-E003'),
    );
  });

  test('reports CAT-F005 for duplicate StableId', () async {
    final result = await loader(
      buildFiles(duplicateId: true),
    ).load();

    expect(result, isA<CatalogLoadFailure>());
    expect(
      result.diagnostics.map((item) => item.code.value),
      contains('CAT-F005'),
    );
  });

  test('returns AppError for general schema failure', () async {
    final result = await loader(
      buildFiles(),
      schemaValidator: const _RejectingSchemaValidator(),
    ).load();

    expect(result, isA<CatalogLoadFailure>());
    expect(result.error, isNotNull);
    expect(
      result.error!.code,
      AppErrorCode.catalogValidationFailed,
    );
    expect(result.diagnostics, isEmpty);
  });
  test('retains CAT-E004 when schema validation also fails', () async {
    final files = buildFiles();
    final originalBytes = files['payment_modes.json']!;
    final document =
        jsonDecode(utf8.decode(originalBytes)) as Map<String, dynamic>;
    final items = document['items']! as List<dynamic>;
    final firstItem = items.first as Map<String, dynamic>;

    firstItem['id'] = 'INVALID';

    final changedBytes = utf8.encode(jsonEncode(document));
    files['payment_modes.json'] = changedBytes;

    final manifest = jsonDecode(
      utf8.decode(files[JsonCatalogLoader.manifestFileName]!),
    ) as Map<String, dynamic>;
    final manifestItems = manifest['items']! as List<dynamic>;

    for (final rawItem in manifestItems) {
      final item = rawItem as Map<String, dynamic>;
      if (item['fileName'] == 'payment_modes.json') {
        item['contentHash'] = hasher.sha256Hex(changedBytes);
      }
    }

    files[JsonCatalogLoader.manifestFileName] =
        utf8.encode(jsonEncode(manifest));

    final result = await loader(
      files,
      schemaValidator: const _RejectingSchemaValidator(),
    ).load();

    expect(result, isA<CatalogLoadFailure>());
    expect(result.error, isNotNull);
    expect(
      result.error!.code,
      AppErrorCode.catalogValidationFailed,
    );
    expect(
      result.diagnostics.map((item) => item.code.value),
      contains('CAT-E004'),
    );
  });
  test('preserves AppError when manifest file is missing', () async {
    final files = buildFiles();
    files.remove(JsonCatalogLoader.manifestFileName);

    final result = await loader(files).load();

    expect(result, isA<CatalogLoadFailure>());
    expect(result.error, isNotNull);
    expect(result.error!.code, AppErrorCode.catalogNotFound);
    expect(
      result.diagnostics.map((item) => item.code.value),
      contains('CAT-F003'),
    );
  });

  test('preserves AppError for malformed manifest JSON', () async {
    final files = buildFiles();
    files[JsonCatalogLoader.manifestFileName] = utf8.encode('{invalid');

    final result = await loader(files).load();

    expect(result, isA<CatalogLoadFailure>());
    expect(result.error, isNotNull);
    expect(result.error!.code, AppErrorCode.catalogDecodeFailed);
    expect(
      result.diagnostics.map((item) => item.code.value),
      contains('CAT-F002'),
    );
  });

  test('preserves AppError for structurally invalid manifest', () async {
    final files = buildFiles();
    files[JsonCatalogLoader.manifestFileName] = utf8.encode('{}');

    final result = await loader(files).load();

    expect(result, isA<CatalogLoadFailure>());
    expect(result.error, isNotNull);
    expect(
      result.error!.code,
      AppErrorCode.catalogValidationFailed,
    );
    expect(
      result.diagnostics.map((item) => item.code.value),
      contains('CAT-F002'),
    );
  });

  test('preserves AppError when a required catalog file is missing', () async {
    final result = await loader(
      buildFiles(missingFile: 'payment_modes.json'),
    ).load();

    expect(result, isA<CatalogLoadFailure>());
    expect(result.error, isNotNull);
    expect(result.error!.code, AppErrorCode.catalogNotFound);
    expect(
      result.diagnostics.map((item) => item.code.value),
      contains('CAT-F003'),
    );
  });
  test(
    'does not emit cascading reference diagnostics when a file is missing',
    () async {
      final files = buildFiles();
      final modeDocument = jsonDecode(
        utf8.decode(files['payment_modes.json']!),
      ) as Map<String, dynamic>;
      final modeItems = modeDocument['items']! as List<dynamic>;
      final mode = modeItems.first as Map<String, dynamic>;

      mode['instrumentId'] = 'item_001';

      final changedBytes = utf8.encode(jsonEncode(modeDocument));
      files['payment_modes.json'] = changedBytes;

      final manifest = jsonDecode(
        utf8.decode(files[JsonCatalogLoader.manifestFileName]!),
      ) as Map<String, dynamic>;
      final manifestItems = manifest['items']! as List<dynamic>;

      for (final rawItem in manifestItems) {
        final item = rawItem as Map<String, dynamic>;
        if (item['fileName'] == 'payment_modes.json') {
          item['contentHash'] = hasher.sha256Hex(changedBytes);
        }
      }

      files[JsonCatalogLoader.manifestFileName] =
          utf8.encode(jsonEncode(manifest));
      files.remove('payment_instruments.json');

      final result = await loader(files).load();

      expect(result, isA<CatalogLoadFailure>());
      expect(
        result.diagnostics.map((item) => item.code.value),
        contains('CAT-F003'),
      );
      expect(
        result.diagnostics.map((item) => item.code.value),
        isNot(contains('CAT-E001')),
      );
    },
  );

  test(
    'does not run cross-document validation after schema failure',
    () async {
      final files = buildFiles();
      final modeDocument = jsonDecode(
        utf8.decode(files['payment_modes.json']!),
      ) as Map<String, dynamic>;
      final modeItems = modeDocument['items']! as List<dynamic>;
      final mode = modeItems.first as Map<String, dynamic>;

      mode['instrumentId'] = 'missing_instrument';

      final changedBytes = utf8.encode(jsonEncode(modeDocument));
      files['payment_modes.json'] = changedBytes;

      final manifest = jsonDecode(
        utf8.decode(files[JsonCatalogLoader.manifestFileName]!),
      ) as Map<String, dynamic>;
      final manifestItems = manifest['items']! as List<dynamic>;

      for (final rawItem in manifestItems) {
        final item = rawItem as Map<String, dynamic>;
        if (item['fileName'] == 'payment_modes.json') {
          item['contentHash'] = hasher.sha256Hex(changedBytes);
        }
      }

      files[JsonCatalogLoader.manifestFileName] =
          utf8.encode(jsonEncode(manifest));

      final result = await loader(
        files,
        schemaValidator: const _RejectingSchemaValidator(),
      ).load();

      expect(result, isA<CatalogLoadFailure>());
      expect(result.error, isNotNull);
      expect(
        result.error!.code,
        AppErrorCode.catalogValidationFailed,
      );
      expect(
        result.diagnostics.map((item) => item.code.value),
        isNot(contains('CAT-E001')),
      );
    },
  );
}

final class _AcceptingSchemaValidator implements CatalogSchemaValidator {
  const _AcceptingSchemaValidator();

  @override
  Future<AppResult<CatalogSchemaValidationResult>> validate({
    required String schemaId,
    required Object? document,
  }) async {
    return AppSuccess<CatalogSchemaValidationResult>(
      CatalogSchemaValidationResult(
        const <CatalogSchemaIssue>[],
      ),
    );
  }
}

final class _RejectingSchemaValidator implements CatalogSchemaValidator {
  const _RejectingSchemaValidator();

  @override
  Future<AppResult<CatalogSchemaValidationResult>> validate({
    required String schemaId,
    required Object? document,
  }) async {
    if (schemaId == JsonCatalogLoader.manifestSchemaId) {
      return AppSuccess<CatalogSchemaValidationResult>(
        CatalogSchemaValidationResult(
          const <CatalogSchemaIssue>[],
        ),
      );
    }

    return AppSuccess<CatalogSchemaValidationResult>(
      CatalogSchemaValidationResult(
        <CatalogSchemaIssue>[
          CatalogSchemaIssue(
            severity: CatalogSchemaIssueSeverity.error,
            message: 'Schema validation failed.',
            instancePath: '/items/0',
            schemaPath: '/properties/items',
          ),
        ],
      ),
    );
  }
}

import 'package:bestpay/application/catalog/catalog_file_source.dart';
import 'package:bestpay/application/catalog/catalog_load_result.dart';
import 'package:bestpay/application/catalog/catalog_loader.dart';
import 'package:bestpay/application/catalog/catalog_schema_validator.dart';
import 'package:bestpay/application/catalog/content_hasher.dart';
import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/catalog_version.dart';
import 'package:bestpay/domain/catalog/catalog_diagnostic.dart';
import 'package:bestpay/domain/catalog/catalog_diagnostic_code.dart';
import 'package:bestpay/domain/catalog/catalog_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CatalogVersion validVersion() {
    final result = CatalogVersion.create('2026.09.19.1');
    return (result as AppSuccess<CatalogVersion>).value;
  }

  CatalogSnapshot validSnapshot() {
    return CatalogSnapshot(
      schemaVersion: '1.0.0',
      catalogVersion: validVersion(),
      generatedAt: DateTime.utc(2026, 9, 19),
      documents: const <String, Object?>{},
    );
  }

  test('CatalogFileData defensively copies bytes', () {
    final sourceBytes = <int>[1, 2, 3];
    final file = CatalogFileData(
      fileName: 'catalog_manifest.json',
      bytes: sourceBytes,
    );

    sourceBytes.add(4);

    expect(file.bytes, <int>[1, 2, 3]);
    expect(() => file.bytes.add(5), throwsUnsupportedError);
  });

  test('schema validation result separates errors and warnings', () {
    final result = CatalogSchemaValidationResult(
      <CatalogSchemaIssue>[
        CatalogSchemaIssue(
          severity: CatalogSchemaIssueSeverity.error,
          message: 'Invalid value.',
        ),
        CatalogSchemaIssue(
          severity: CatalogSchemaIssueSeverity.warning,
          message: 'Review value.',
        ),
      ],
    );

    expect(result.isValid, isFalse);
    expect(result.errors, hasLength(1));
    expect(result.warnings, hasLength(1));
    expect(() => result.issues.clear(), throwsUnsupportedError);
  });

  test('application ports do not expose infrastructure types', () async {
    final source = _MemorySource();
    final schemaValidator = _AcceptingSchemaValidator();
    final hasher = _KnownHasher();
    final loader = _SuccessfulLoader(validSnapshot());

    expect(
      await source.read('catalog_manifest.json'),
      isA<AppSuccess<CatalogFileData>>(),
    );

    final validationResult = await schemaValidator.validate(
      schemaId: 'urn:bestpay:schema:catalog-manifest:1.0.0',
      document: const <String, Object?>{},
    );

    expect(
      validationResult,
      isA<AppSuccess<CatalogSchemaValidationResult>>(),
    );

    expect(hasher.sha256Hex(const <int>[97, 98, 99]), 'known-hash');

    final loadResult = await loader.load();
    expect(loadResult, isA<CatalogLoadSuccess>());
    expect(loadResult.succeeded, isTrue);
  });

  test('technical error is sufficient for load failure', () {
    final error = AppError(
      code: AppErrorCode.catalogDecodeFailed,
      operation: 'catalog.load',
    );

    final failure = CatalogLoadFailure(error: error);

    expect(failure.failed, isTrue);
    expect(failure.error, same(error));
    expect(failure.diagnostics, isEmpty);
  });

  test('blocking diagnostic is sufficient for load failure', () {
    final failure = CatalogLoadFailure(
      diagnostics: <CatalogDiagnostic>[
        CatalogDiagnostic(
          code: CatalogDiagnosticCode.parse('CAT-E001'),
          message: 'Broken reference.',
        ),
      ],
    );

    expect(failure.failed, isTrue);
    expect(failure.error, isNull);
    expect(failure.diagnostics, hasLength(1));
  });

  test('warning alone is not a valid load failure', () {
    expect(
      () => CatalogLoadFailure(
        diagnostics: <CatalogDiagnostic>[
          CatalogDiagnostic(
            code: CatalogDiagnosticCode.parse('CAT-W001'),
            message: 'Warning only.',
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}

final class _MemorySource implements CatalogFileSource {
  @override
  Future<AppResult<CatalogFileData>> read(String fileName) async {
    return AppSuccess<CatalogFileData>(
      CatalogFileData(
        fileName: fileName,
        bytes: const <int>[123, 125],
      ),
    );
  }
}

final class _AcceptingSchemaValidator implements CatalogSchemaValidator {
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

final class _KnownHasher implements ContentHasher {
  @override
  String sha256Hex(List<int> bytes) => 'known-hash';
}

final class _SuccessfulLoader implements CatalogLoader {
  const _SuccessfulLoader(this.snapshot);

  final CatalogSnapshot snapshot;

  @override
  Future<CatalogLoadResult> load() async {
    return CatalogLoadSuccess(snapshot);
  }
}

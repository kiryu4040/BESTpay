import 'dart:convert';

import '../../application/catalog/catalog_file_source.dart';
import '../../application/catalog/catalog_load_result.dart';
import '../../application/catalog/catalog_loader.dart';
import '../../application/catalog/catalog_schema_validator.dart';
import '../../application/catalog/content_hasher.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/app_error_code.dart';
import '../../core/result/app_result.dart';
import '../../core/value_objects/catalog_version.dart';
import '../../core/value_objects/stable_id.dart';
import '../../domain/catalog/catalog_diagnostic.dart';
import '../../domain/catalog/catalog_diagnostic_code.dart';
import '../../domain/catalog/catalog_integrity_validator.dart';
import '../../domain/catalog/catalog_manifest.dart';
import '../../domain/catalog/catalog_snapshot.dart';
import 'json_catalog_manifest_decoder.dart';

/// Loads the manifest and all twelve catalog documents.
///
/// This loader performs transport, hash, decoding, schema, version, and ID
/// checks. Cross-reference and cycle validation are separate domain steps.
final class JsonCatalogLoader implements CatalogLoader {
  const JsonCatalogLoader({
    required CatalogFileSource fileSource,
    required CatalogSchemaValidator schemaValidator,
    required ContentHasher contentHasher,
    JsonCatalogManifestDecoder manifestDecoder =
        const JsonCatalogManifestDecoder(),
    CatalogIntegrityValidator integrityValidator =
        const CatalogIntegrityValidator(),
  })  : _fileSource = fileSource,
        _schemaValidator = schemaValidator,
        _contentHasher = contentHasher,
        _manifestDecoder = manifestDecoder,
        _integrityValidator = integrityValidator;

  static const String manifestFileName = 'catalog_manifest.json';
  static const String manifestSchemaId =
      'urn:bestpay:schema:catalog-manifest:1.0.0';

  final CatalogFileSource _fileSource;
  final CatalogSchemaValidator _schemaValidator;
  final ContentHasher _contentHasher;
  final JsonCatalogManifestDecoder _manifestDecoder;
  final CatalogIntegrityValidator _integrityValidator;

  @override
  Future<CatalogLoadResult> load() async {
    final manifestRead = await _fileSource.read(manifestFileName);

    if (manifestRead is AppFailure<CatalogFileData>) {
      return CatalogLoadFailure(
        error: manifestRead.error,
        diagnostics: <CatalogDiagnostic>[
          _diagnostic(
            'CAT-F003',
            'The required catalog manifest could not be read.',
            path: manifestFileName,
          ),
        ],
      );
    }

    final manifestFile = (manifestRead as AppSuccess<CatalogFileData>).value;

    final manifestDocumentResult = _decodeManifest(manifestFile.bytes);

    if (manifestDocumentResult is AppFailure<Map<String, dynamic>>) {
      return CatalogLoadFailure(
        error: manifestDocumentResult.error,
        diagnostics: <CatalogDiagnostic>[
          _diagnostic(
            'CAT-F002',
            'The catalog manifest could not be parsed.',
            path: manifestFileName,
          ),
        ],
      );
    }

    final manifestDocument =
        (manifestDocumentResult as AppSuccess<Map<String, dynamic>>).value;

    final manifestSchemaVersion = manifestDocument['schemaVersion'];
    if (manifestSchemaVersion is String && manifestSchemaVersion != '1.0.0') {
      return CatalogLoadFailure(
        diagnostics: <CatalogDiagnostic>[
          _diagnostic(
            'CAT-F001',
            'The catalog manifest schema version is unsupported.',
            path: '/schemaVersion',
            context: <String, Object?>{
              'actual': manifestSchemaVersion,
              'expected': '1.0.0',
            },
          ),
        ],
      );
    }

    final manifestResult = _manifestDecoder.decode(
      manifestFile.bytes,
    );

    if (manifestResult is AppFailure<CatalogManifest>) {
      return CatalogLoadFailure(
        error: manifestResult.error,
        diagnostics: <CatalogDiagnostic>[
          _diagnostic(
            'CAT-F002',
            'The catalog manifest is structurally invalid.',
            path: manifestFileName,
          ),
        ],
      );
    }

    final manifest = (manifestResult as AppSuccess<CatalogManifest>).value;

    final manifestSchemaFailure = await _validateSchema(
      fileName: manifestFileName,
      schemaId: manifestSchemaId,
      document: manifestDocument,
    );

    if (manifestSchemaFailure != null) {
      return manifestSchemaFailure;
    }

    final documents = <String, Object?>{};
    final itemsById = <String, Object?>{};
    final diagnostics = <CatalogDiagnostic>[];
    AppError? technicalError;
    var canValidateCrossDocumentIntegrity = true;

    for (final fileName in CatalogManifest.expectedSchemaIds.keys) {
      final manifestItem = manifest.itemsByFileName[fileName]!;

      final readResult = await _fileSource.read(fileName);

      if (readResult is AppFailure<CatalogFileData>) {
        technicalError ??= readResult.error;
        canValidateCrossDocumentIntegrity = false;
        diagnostics.add(
          _diagnostic(
            'CAT-F003',
            'A required catalog file could not be read.',
            path: fileName,
          ),
        );
        continue;
      }

      final fileData = (readResult as AppSuccess<CatalogFileData>).value;

      final actualHash = _contentHasher.sha256Hex(fileData.bytes);

      if (actualHash != manifestItem.contentHash) {
        canValidateCrossDocumentIntegrity = false;
        diagnostics.add(
          _diagnostic(
            'CAT-F004',
            'The catalog file hash does not match the manifest.',
            path: fileName,
            context: <String, Object?>{
              'expectedHash': manifestItem.contentHash,
              'actualHash': actualHash,
            },
          ),
        );
        continue;
      }

      final documentResult = _decodeCatalogDocument(
        fileName,
        fileData.bytes,
      );

      if (documentResult is AppFailure<Map<String, dynamic>>) {
        return CatalogLoadFailure(
          error: documentResult.error,
          diagnostics: diagnostics,
        );
      }

      final document =
          (documentResult as AppSuccess<Map<String, dynamic>>).value;

      final schemaVersion = document['schemaVersion'];
      if (schemaVersion is String && schemaVersion != '1.0.0') {
        canValidateCrossDocumentIntegrity = false;
        diagnostics.add(
          _diagnostic(
            'CAT-F001',
            'A catalog file uses an unsupported schema version.',
            path: '$fileName/schemaVersion',
            context: <String, Object?>{
              'actual': schemaVersion,
              'expected': '1.0.0',
            },
          ),
        );
        continue;
      }

      final catalogVersionText = document['catalogVersion'];

      if (catalogVersionText is String) {
        final versionResult = CatalogVersion.create(catalogVersionText);

        if (versionResult is! AppSuccess<CatalogVersion> ||
            versionResult.value != manifest.catalogVersion) {
          diagnostics.add(
            _diagnostic(
              'CAT-E003',
              'CatalogVersion is invalid or does not match the manifest.',
              path: '$fileName/catalogVersion',
              context: <String, Object?>{
                'actual': catalogVersionText,
                'expected': manifest.catalogVersion.value,
              },
            ),
          );
        }
      }

      documents[fileName] = document;

      _collectStableIds(
        fileName: fileName,
        document: document,
        itemsById: itemsById,
        diagnostics: diagnostics,
      );

      final schemaFailure = await _validateSchema(
        fileName: fileName,
        schemaId: manifestItem.schemaId,
        document: document,
      );

      if (schemaFailure != null) {
        technicalError ??= schemaFailure.error;
        canValidateCrossDocumentIntegrity = false;
      }
    }

    if (canValidateCrossDocumentIntegrity) {
      diagnostics.addAll(
        _integrityValidator.validate(documents),
      );
    }

    if (technicalError != null ||
        diagnostics.any(
          (diagnostic) => diagnostic.blocksPublication,
        )) {
      return CatalogLoadFailure(
        error: technicalError,
        diagnostics: diagnostics,
      );
    }

    return CatalogLoadSuccess(
      CatalogSnapshot(
        schemaVersion: manifest.schemaVersion,
        catalogVersion: manifest.catalogVersion,
        generatedAt: manifest.generatedAt,
        documents: documents,
        indexes: <String, Object?>{
          'itemsById': itemsById,
        },
        diagnostics: diagnostics,
      ),
    );
  }

  AppResult<Map<String, dynamic>> _decodeManifest(
    List<int> bytes,
  ) {
    try {
      final decoded = jsonDecode(
        utf8.decode(bytes, allowMalformed: false),
      );

      if (decoded is! Map) {
        throw const FormatException(
          'Manifest root must be an object.',
        );
      }

      return AppSuccess<Map<String, dynamic>>(
        Map<String, dynamic>.from(decoded),
      );
    } on Object catch (error) {
      return AppFailure<Map<String, dynamic>>(
        AppError(
          code: AppErrorCode.catalogDecodeFailed,
          operation: 'catalogManifest.decode',
          causeType: error.runtimeType.toString(),
        ),
      );
    }
  }

  AppResult<Map<String, dynamic>> _decodeCatalogDocument(
    String fileName,
    List<int> bytes,
  ) {
    try {
      final decoded = jsonDecode(
        utf8.decode(bytes, allowMalformed: false),
      );

      if (decoded is! Map) {
        throw const FormatException(
          'Catalog document root must be an object.',
        );
      }

      return AppSuccess<Map<String, dynamic>>(
        Map<String, dynamic>.from(decoded),
      );
    } on Object catch (error) {
      return AppFailure<Map<String, dynamic>>(
        AppError(
          code: AppErrorCode.catalogDecodeFailed,
          operation: 'catalogDocument.decode',
          context: <String, Object?>{
            'fileName': fileName,
          },
          causeType: error.runtimeType.toString(),
        ),
      );
    }
  }

  Future<CatalogLoadFailure?> _validateSchema({
    required String fileName,
    required String schemaId,
    required Object? document,
  }) async {
    final result = await _schemaValidator.validate(
      schemaId: schemaId,
      document: document,
    );

    if (result is AppFailure<CatalogSchemaValidationResult>) {
      return CatalogLoadFailure(error: result.error);
    }

    final validation =
        (result as AppSuccess<CatalogSchemaValidationResult>).value;

    if (validation.isValid) {
      return null;
    }

    final firstError = validation.errors.first;

    return CatalogLoadFailure(
      error: AppError(
        code: AppErrorCode.catalogValidationFailed,
        operation: 'catalogSchema.validate',
        context: <String, Object?>{
          'fileName': fileName,
          'schemaId': schemaId,
          'instancePath': firstError.instancePath,
          'schemaPath': firstError.schemaPath,
          'issueCount': validation.errors.length,
        },
        safeMessage: 'Catalog data does not match its schema.',
      ),
    );
  }

  void _collectStableIds({
    required String fileName,
    required Map<String, dynamic> document,
    required Map<String, Object?> itemsById,
    required List<CatalogDiagnostic> diagnostics,
  }) {
    final items = document['items'];
    if (items is! List) {
      return;
    }

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      if (item is! Map) {
        continue;
      }

      final id = item['id'];
      if (id is! String) {
        continue;
      }

      final stableIdResult = StableId.create(id);

      if (stableIdResult is! AppSuccess<StableId>) {
        diagnostics.add(
          _diagnostic(
            'CAT-E004',
            'The catalog item ID is not a valid StableId.',
            path: '$fileName/items/$index/id',
            context: <String, Object?>{
              'id': id,
            },
          ),
        );
        continue;
      }

      if (itemsById.containsKey(id)) {
        diagnostics.add(
          _diagnostic(
            'CAT-F005',
            'The StableId is duplicated across catalog files.',
            path: '$fileName/items/$index/id',
            context: <String, Object?>{
              'id': id,
            },
          ),
        );
        continue;
      }

      itemsById[id] = <String, Object?>{
        'fileName': fileName,
        'item': item,
      };
    }
  }

  CatalogDiagnostic _diagnostic(
    String code,
    String message, {
    String? path,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    return CatalogDiagnostic(
      code: CatalogDiagnosticCode.parse(code),
      message: message,
      path: path,
      context: context,
    );
  }
}

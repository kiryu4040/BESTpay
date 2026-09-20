import 'dart:convert';

import '../../core/errors/app_error.dart';
import '../../core/errors/app_error_code.dart';
import '../../core/result/app_result.dart';
import '../../core/value_objects/catalog_version.dart';
import '../../domain/catalog/catalog_manifest.dart';

/// Decodes and structurally validates catalog_manifest.json.
final class JsonCatalogManifestDecoder {
  const JsonCatalogManifestDecoder();

  AppResult<CatalogManifest> decode(List<int> bytes) {
    late final Object? decoded;

    try {
      decoded = jsonDecode(
        utf8.decode(
          bytes,
          allowMalformed: false,
        ),
      );
    } on FormatException catch (error) {
      return AppFailure<CatalogManifest>(
        AppError(
          code: AppErrorCode.catalogDecodeFailed,
          operation: 'catalogManifest.decode',
          causeType: error.runtimeType.toString(),
        ),
      );
    }

    try {
      if (decoded is! Map) {
        throw const FormatException(
          'Catalog manifest root must be an object.',
        );
      }

      final manifest = Map<String, dynamic>.from(decoded);
      final schemaVersion = _requiredString(manifest, 'schemaVersion');
      final catalogVersionText = _requiredString(manifest, 'catalogVersion');
      final generatedAtText = _requiredString(manifest, 'generatedAt');

      final catalogVersionResult = CatalogVersion.create(catalogVersionText);

      if (catalogVersionResult is! AppSuccess<CatalogVersion>) {
        throw const FormatException(
          'Invalid catalogVersion.',
        );
      }

      final generatedAt = DateTime.tryParse(generatedAtText);
      if (generatedAt == null) {
        throw const FormatException(
          'Invalid generatedAt.',
        );
      }

      final rawItems = manifest['items'];
      if (rawItems is! List) {
        throw const FormatException(
          'Manifest items must be an array.',
        );
      }

      final items = <CatalogManifestItem>[];

      for (final rawItem in rawItems) {
        if (rawItem is! Map) {
          throw const FormatException(
            'Manifest item must be an object.',
          );
        }

        final item = Map<String, dynamic>.from(rawItem);

        items.add(
          CatalogManifestItem(
            fileName: _requiredString(item, 'fileName'),
            schemaId: _requiredString(item, 'schemaId'),
            contentHash: _requiredString(item, 'contentHash'),
            isRequired: _requiredBool(item, 'required'),
          ),
        );
      }

      return AppSuccess<CatalogManifest>(
        CatalogManifest(
          schemaVersion: schemaVersion,
          catalogVersion: catalogVersionResult.value,
          generatedAt: generatedAt,
          items: items,
        ),
      );
    } on FormatException catch (error) {
      return _validationFailure(error);
    } on ArgumentError catch (error) {
      return _validationFailure(error);
    } on TypeError catch (error) {
      return _validationFailure(error);
    }
  }

  static String _requiredString(
    Map<String, dynamic> source,
    String key,
  ) {
    final value = source[key];

    if (value is! String) {
      throw FormatException('$key must be a string.');
    }

    return value;
  }

  static bool _requiredBool(
    Map<String, dynamic> source,
    String key,
  ) {
    final value = source[key];

    if (value is! bool) {
      throw FormatException('$key must be a boolean.');
    }

    return value;
  }

  static AppFailure<CatalogManifest> _validationFailure(
    Object error,
  ) {
    return AppFailure<CatalogManifest>(
      AppError(
        code: AppErrorCode.catalogValidationFailed,
        operation: 'catalogManifest.validate',
        causeType: error.runtimeType.toString(),
      ),
    );
  }
}

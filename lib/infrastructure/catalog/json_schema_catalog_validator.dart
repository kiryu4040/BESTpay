import 'dart:convert';

import 'package:json_schema/json_schema.dart';

import '../../application/catalog/catalog_schema_validator.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/app_error_code.dart';
import '../../core/result/app_result.dart';

/// Draft 2020-12 validator backed by a closed, in-memory schema registry.
///
/// Schema maps are copied before compilation. References are resolved only
/// against the supplied registry; this adapter does not perform network I/O.
final class JsonSchemaCatalogValidator implements CatalogSchemaValidator {
  JsonSchemaCatalogValidator._(
    Map<String, JsonSchema> compiledSchemas,
  ) : _compiledSchemas = Map<String, JsonSchema>.unmodifiable(compiledSchemas);

  factory JsonSchemaCatalogValidator({
    required Map<String, Map<String, dynamic>> schemasById,
  }) {
    final copiedSchemas = <String, Map<String, dynamic>>{};

    for (final entry in schemasById.entries) {
      final copied = jsonDecode(jsonEncode(entry.value));

      if (copied is! Map) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Schema must be a JSON object.',
        );
      }

      final schema = Map<String, dynamic>.from(copied);

      if (schema[r'$id'] != entry.key) {
        throw ArgumentError.value(
          schema[r'$id'],
          entry.key,
          r'Registry key must match the schema `$id`.',
        );
      }

      copiedSchemas[entry.key] = schema;
    }

    final refProvider = RefProvider.sync((String reference) {
      final fragmentIndex = reference.indexOf('#');
      final schemaId =
          fragmentIndex < 0 ? reference : reference.substring(0, fragmentIndex);

      if (schemaId.isEmpty) {
        return null;
      }

      return copiedSchemas[schemaId];
    });

    final compiledSchemas = <String, JsonSchema>{};

    for (final entry in copiedSchemas.entries) {
      compiledSchemas[entry.key] = JsonSchema.create(
        entry.value,
        schemaVersion: SchemaVersion.draft2020_12,
        refProvider: refProvider,
      );
    }

    return JsonSchemaCatalogValidator._(compiledSchemas);
  }

  final Map<String, JsonSchema> _compiledSchemas;

  Set<String> get schemaIds => Set<String>.unmodifiable(_compiledSchemas.keys);

  @override
  Future<AppResult<CatalogSchemaValidationResult>> validate({
    required String schemaId,
    required Object? document,
  }) async {
    final schema = _compiledSchemas[schemaId];

    if (schema == null) {
      return AppFailure<CatalogSchemaValidationResult>(
        AppError(
          code: AppErrorCode.catalogValidationFailed,
          operation: 'catalogSchema.validate',
          context: <String, Object?>{
            'schemaId': schemaId,
            'reason': 'schemaNotRegistered',
          },
        ),
      );
    }

    try {
      final result = schema.validate(document);
      final issues = <CatalogSchemaIssue>[];

      for (final error in result.errors) {
        issues.add(
          CatalogSchemaIssue(
            severity: CatalogSchemaIssueSeverity.error,
            message: error.message,
            instancePath:
                error.instancePath.isEmpty ? null : error.instancePath,
            schemaPath: error.schemaPath.isEmpty ? null : error.schemaPath,
          ),
        );
      }

      for (final warning in result.warnings) {
        issues.add(
          CatalogSchemaIssue(
            severity: CatalogSchemaIssueSeverity.warning,
            message: warning.message,
            instancePath:
                warning.instancePath.isEmpty ? null : warning.instancePath,
            schemaPath: warning.schemaPath.isEmpty ? null : warning.schemaPath,
          ),
        );
      }

      return AppSuccess<CatalogSchemaValidationResult>(
        CatalogSchemaValidationResult(issues),
      );
    } on Object catch (error) {
      return AppFailure<CatalogSchemaValidationResult>(
        AppError(
          code: AppErrorCode.catalogValidationFailed,
          operation: 'catalogSchema.validate',
          context: <String, Object?>{
            'schemaId': schemaId,
            'reason': 'schemaEngineFailure',
          },
          causeType: error.runtimeType.toString(),
        ),
      );
    }
  }
}

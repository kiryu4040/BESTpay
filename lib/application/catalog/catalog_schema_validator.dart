import '../../core/result/app_result.dart';

/// Severity reported directly by the JSON Schema engine.
///
/// This is intentionally separate from CatalogDiagnosticSeverity because a
/// generic schema issue must not be assigned an unrelated CAT code.
enum CatalogSchemaIssueSeverity {
  error,
  warning,
}

/// One technical issue produced by JSON Schema validation.
final class CatalogSchemaIssue {
  CatalogSchemaIssue({
    required this.severity,
    required this.message,
    this.instancePath,
    this.schemaPath,
  }) {
    if (message.trim().isEmpty) {
      throw ArgumentError.value(
        message,
        'message',
        'Schema issue message must not be blank.',
      );
    }
  }

  final CatalogSchemaIssueSeverity severity;
  final String message;
  final String? instancePath;
  final String? schemaPath;
}

/// Immutable result returned by a JSON Schema validator.
final class CatalogSchemaValidationResult {
  CatalogSchemaValidationResult(
    Iterable<CatalogSchemaIssue> issues,
  ) : issues = List<CatalogSchemaIssue>.unmodifiable(issues);

  final List<CatalogSchemaIssue> issues;

  bool get isValid => issues.every(
        (issue) => issue.severity != CatalogSchemaIssueSeverity.error,
      );

  List<CatalogSchemaIssue> get errors => List<CatalogSchemaIssue>.unmodifiable(
        issues.where(
          (issue) => issue.severity == CatalogSchemaIssueSeverity.error,
        ),
      );

  List<CatalogSchemaIssue> get warnings =>
      List<CatalogSchemaIssue>.unmodifiable(
        issues.where(
          (issue) => issue.severity == CatalogSchemaIssueSeverity.warning,
        ),
      );
}

/// Port for validating one decoded document against a registered schema.
///
/// Infrastructure or registry failures are returned as AppFailure.
/// A successfully executed validation returns AppSuccess even when the
/// document is invalid; inspect CatalogSchemaValidationResult.isValid.
abstract interface class CatalogSchemaValidator {
  Future<AppResult<CatalogSchemaValidationResult>> validate({
    required String schemaId,
    required Object? document,
  });
}

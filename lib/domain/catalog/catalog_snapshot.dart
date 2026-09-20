import '../../core/value_objects/catalog_version.dart';
import 'catalog_diagnostic.dart';

/// An immutable catalog that has passed all publication-blocking validation.
final class CatalogSnapshot {
  CatalogSnapshot._({
    required this.schemaVersion,
    required this.catalogVersion,
    required this.generatedAt,
    required this.documents,
    required this.indexes,
    required this.diagnostics,
  });

  factory CatalogSnapshot({
    required String schemaVersion,
    required CatalogVersion catalogVersion,
    required DateTime generatedAt,
    required Map<String, Object?> documents,
    Map<String, Object?> indexes = const <String, Object?>{},
    Iterable<CatalogDiagnostic> diagnostics = const <CatalogDiagnostic>[],
  }) {
    if (schemaVersion.trim().isEmpty) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'Schema version must not be blank.',
      );
    }

    final frozenDiagnostics = List<CatalogDiagnostic>.unmodifiable(diagnostics);

    if (frozenDiagnostics.any(
      (diagnostic) => diagnostic.blocksPublication,
    )) {
      throw ArgumentError(
        'A catalog snapshot cannot contain a fatal or error diagnostic.',
      );
    }

    return CatalogSnapshot._(
      schemaVersion: schemaVersion,
      catalogVersion: catalogVersion,
      generatedAt: generatedAt,
      documents: _freezeStringMap(documents),
      indexes: _freezeStringMap(indexes),
      diagnostics: frozenDiagnostics,
    );
  }

  final String schemaVersion;
  final CatalogVersion catalogVersion;
  final DateTime generatedAt;

  /// Catalog documents keyed by manifest file name.
  final Map<String, Object?> documents;

  /// Derived indexes keyed by their stable index names.
  final Map<String, Object?> indexes;

  /// Only warning and info diagnostics can be present in a snapshot.
  final List<CatalogDiagnostic> diagnostics;
}

Map<String, Object?> _freezeStringMap(Map<String, Object?> source) {
  return Map<String, Object?>.unmodifiable(
    source.map(
      (key, value) => MapEntry<String, Object?>(
        key,
        _freezeJsonValue(value),
      ),
    ),
  );
}

Object? _freezeJsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }

  if (value is List) {
    return List<Object?>.unmodifiable(
      value.map<Object?>(_freezeJsonValue),
    );
  }

  if (value is Map) {
    final result = <String, Object?>{};

    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError.value(
          entry.key,
          'source',
          'Catalog map keys must be strings.',
        );
      }

      result[entry.key as String] = _freezeJsonValue(entry.value);
    }

    return Map<String, Object?>.unmodifiable(result);
  }

  throw ArgumentError.value(
    value,
    'source',
    'Catalog values must be JSON-compatible.',
  );
}

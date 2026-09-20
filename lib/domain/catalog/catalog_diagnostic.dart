import 'catalog_diagnostic_code.dart';
import 'catalog_diagnostic_severity.dart';

/// A structured problem discovered while loading or validating a catalog.
///
/// [message] is developer-facing and must not contain secrets.
/// [context] is defensively copied and should contain JSON-compatible values.
final class CatalogDiagnostic {
  CatalogDiagnostic._({
    required this.code,
    required this.message,
    required this.path,
    required this.context,
  });

  factory CatalogDiagnostic({
    required CatalogDiagnosticCode code,
    required String message,
    String? path,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    if (message.trim().isEmpty) {
      throw ArgumentError.value(
        message,
        'message',
        'A catalog diagnostic message must not be blank.',
      );
    }

    return CatalogDiagnostic._(
      code: code,
      message: message,
      path: path,
      context: _freezeStringMap(context),
    );
  }

  final CatalogDiagnosticCode code;
  final String message;

  /// JSON Pointer, file name, or another stable diagnostic location.
  final String? path;

  final Map<String, Object?> context;

  CatalogDiagnosticSeverity get severity => code.severity;

  bool get blocksPublication => severity.blocksPublication;

  @override
  String toString() {
    final location = path == null ? '' : ' at $path';
    return '${code.value}$location: $message';
  }
}

Map<String, Object?> _freezeStringMap(Map<String, Object?> source) {
  return Map<String, Object?>.unmodifiable(
    source.map(
      (key, value) => MapEntry<String, Object?>(
        key,
        _freezeValue(value),
      ),
    ),
  );
}

Object? _freezeValue(Object? value) {
  if (value is Map) {
    final result = <String, Object?>{};

    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError.value(
          key,
          'context',
          'Catalog diagnostic context map keys must be strings.',
        );
      }
      result[key] = _freezeValue(entry.value);
    }

    return Map<String, Object?>.unmodifiable(result);
  }

  if (value is List) {
    return List<Object?>.unmodifiable(
      value.map<Object?>(_freezeValue),
    );
  }

  return value;
}

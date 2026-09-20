import 'catalog_diagnostic_severity.dart';

/// A stable, machine-readable catalog diagnostic code.
///
/// The valid ranges are defined by the integration checkpoint:
///
/// - CAT-F001 through CAT-F007
/// - CAT-E001 through CAT-E013
/// - CAT-W001 through CAT-W010
/// - CAT-I001 through CAT-I004
///
/// The string value, rather than an enum index, is the stable representation.
final class CatalogDiagnosticCode {
  const CatalogDiagnosticCode._({
    required this.value,
    required this.severity,
    required this.number,
  });

  static final RegExp _pattern = RegExp(
    r'^CAT-([FEWI])([0-9]{3})$',
  );

  static const Map<String, int> _maximumByMarker = <String, int>{
    'F': 7,
    'E': 13,
    'W': 10,
    'I': 4,
  };

  final String value;
  final CatalogDiagnosticSeverity severity;
  final int number;

  static CatalogDiagnosticCode parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null || match.end != value.length) {
      throw FormatException('Invalid catalog diagnostic code.', value);
    }

    final marker = match.group(1)!;
    final number = int.parse(match.group(2)!);
    final maximum = _maximumByMarker[marker];

    if (maximum == null || number < 1 || number > maximum) {
      throw FormatException(
        'Catalog diagnostic code is outside its reserved range.',
        value,
      );
    }

    return CatalogDiagnosticCode._(
      value: value,
      severity: CatalogDiagnosticSeverity.fromMarker(marker),
      number: number,
    );
  }

  static CatalogDiagnosticCode? tryParse(String value) {
    try {
      return parse(value);
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogDiagnosticCode && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

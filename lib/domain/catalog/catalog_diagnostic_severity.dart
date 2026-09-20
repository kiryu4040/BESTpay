/// Severity of a catalog diagnostic.
///
/// Fatal and error diagnostics prevent publication of a catalog snapshot.
enum CatalogDiagnosticSeverity {
  fatal(marker: 'F', blocksPublication: true),
  error(marker: 'E', blocksPublication: true),
  warning(marker: 'W', blocksPublication: false),
  info(marker: 'I', blocksPublication: false);

  const CatalogDiagnosticSeverity({
    required this.marker,
    required this.blocksPublication,
  });

  final String marker;
  final bool blocksPublication;

  static CatalogDiagnosticSeverity fromMarker(String marker) {
    return switch (marker) {
      'F' => CatalogDiagnosticSeverity.fatal,
      'E' => CatalogDiagnosticSeverity.error,
      'W' => CatalogDiagnosticSeverity.warning,
      'I' => CatalogDiagnosticSeverity.info,
      _ => throw FormatException(
          'Unknown catalog diagnostic severity marker.',
          marker,
        ),
    };
  }
}

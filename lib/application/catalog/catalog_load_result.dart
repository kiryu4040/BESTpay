import '../../core/errors/app_error.dart';
import '../../domain/catalog/catalog_diagnostic.dart';
import '../../domain/catalog/catalog_snapshot.dart';

/// Result of a complete catalog loading attempt.
sealed class CatalogLoadResult {
  const CatalogLoadResult();

  AppError? get error;
  List<CatalogDiagnostic> get diagnostics;

  bool get succeeded => this is CatalogLoadSuccess;
  bool get failed => this is CatalogLoadFailure;
}

/// A successfully published catalog snapshot.
final class CatalogLoadSuccess extends CatalogLoadResult {
  const CatalogLoadSuccess(this.snapshot);

  final CatalogSnapshot snapshot;

  @override
  AppError? get error => null;

  @override
  List<CatalogDiagnostic> get diagnostics => snapshot.diagnostics;
}

/// A rejected catalog.
///
/// A failure must contain either a technical [error] or at least one
/// publication-blocking catalog diagnostic.
final class CatalogLoadFailure extends CatalogLoadResult {
  CatalogLoadFailure({
    this.error,
    Iterable<CatalogDiagnostic> diagnostics = const <CatalogDiagnostic>[],
  }) : diagnostics = List<CatalogDiagnostic>.unmodifiable(diagnostics) {
    final hasBlockingDiagnostic = this.diagnostics.any(
          (diagnostic) => diagnostic.blocksPublication,
        );

    if (error == null && !hasBlockingDiagnostic) {
      throw ArgumentError(
        'A failed catalog load requires an AppError or a '
        'fatal/error CatalogDiagnostic.',
      );
    }
  }

  @override
  final AppError? error;

  @override
  final List<CatalogDiagnostic> diagnostics;
}

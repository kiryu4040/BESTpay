import 'catalog_load_result.dart';

/// Application boundary for loading and validating one complete catalog.
abstract interface class CatalogLoader {
  Future<CatalogLoadResult> load();
}

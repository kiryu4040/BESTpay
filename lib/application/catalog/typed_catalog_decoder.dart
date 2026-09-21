import '../../core/result/app_result.dart';
import '../../domain/catalog/catalog_snapshot.dart';
import '../../domain/catalog/models/typed_catalog.dart';

/// Converts a fully validated raw catalog snapshot into typed domain models.
///
/// Implementations must return a failure without exposing a partial catalog
/// when any document cannot be converted.
abstract interface class TypedCatalogDecoder {
  AppResult<TypedCatalog> decode(CatalogSnapshot snapshot);
}

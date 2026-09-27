import 'package:bestpay/domain/catalog/catalog.dart';

/// Contract for loading the typed catalog.
///
/// Implementations must never throw: a missing, corrupt, or empty catalog is
/// represented as [Catalog.empty] so the app always starts (D-61).
abstract interface class CatalogRepository {
  Future<Catalog> load();
}

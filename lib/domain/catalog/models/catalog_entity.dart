import '../../../core/value_objects/stable_id.dart';

/// Common identity contract for typed catalog records.
abstract interface class CatalogEntity {
  StableId get id;
}

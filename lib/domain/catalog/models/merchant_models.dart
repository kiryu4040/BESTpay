import '../../../core/value_objects/stable_id.dart';
import 'catalog_entity.dart';
import 'catalog_types.dart';

/// A merchant that can be selected or matched by reward rules.
final class Merchant implements CatalogEntity {
  Merchant({
    required this.id,
    required this.name,
    required Iterable<StableId> merchantGroupIds,
    required Iterable<StableId> categoryIds,
    required Iterable<StableId> locationIds,
    required this.status,
    required Iterable<StableId> sourceIds,
    required Iterable<String> notes,
  })  : merchantGroupIds = _freezeUniqueIds(
          merchantGroupIds,
          'merchantGroupIds',
        ),
        categoryIds = _freezeUniqueIds(categoryIds, 'categoryIds'),
        locationIds = _freezeUniqueIds(locationIds, 'locationIds'),
        sourceIds = _freezeUniqueIds(sourceIds, 'sourceIds'),
        notes = _freezeUniqueText(notes, 'notes') {
    _requireNonEmpty(name, 'name');
  }

  @override
  final StableId id;
  final String name;
  final List<StableId> merchantGroupIds;
  final List<StableId> categoryIds;
  final List<StableId> locationIds;
  final CatalogItemStatus status;
  final List<StableId> sourceIds;
  final List<String> notes;
}

/// A named collection of merchants.
final class MerchantGroup implements CatalogEntity {
  MerchantGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required Iterable<StableId> sourceIds,
    required Iterable<String> notes,
  })  : sourceIds = _freezeUniqueIds(sourceIds, 'sourceIds'),
        notes = _freezeUniqueText(notes, 'notes') {
    _requireNonEmpty(name, 'name');
  }

  @override
  final StableId id;
  final String name;

  /// May be empty because the JSON Schema does not require a minimum length.
  final String description;

  final CatalogItemStatus status;
  final List<StableId> sourceIds;
  final List<String> notes;
}

/// One node in the merchant-category hierarchy.
final class MerchantCategory implements CatalogEntity {
  MerchantCategory({
    required this.id,
    required this.name,
    required this.parentCategoryId,
    required this.status,
    required Iterable<StableId> sourceIds,
    required Iterable<String> notes,
  })  : sourceIds = _freezeUniqueIds(sourceIds, 'sourceIds'),
        notes = _freezeUniqueText(notes, 'notes') {
    _requireNonEmpty(name, 'name');
  }

  @override
  final StableId id;
  final String name;
  final StableId? parentCategoryId;
  final CatalogItemStatus status;
  final List<StableId> sourceIds;
  final List<String> notes;
}

List<StableId> _freezeUniqueIds(
  Iterable<StableId> values,
  String fieldName,
) {
  final result = List<StableId>.of(values);

  if (result.toSet().length != result.length) {
    throw ArgumentError.value(
      values,
      fieldName,
      'Values must be unique.',
    );
  }

  return List<StableId>.unmodifiable(result);
}

List<String> _freezeUniqueText(
  Iterable<String> values,
  String fieldName,
) {
  final result = List<String>.of(values);

  for (final value in result) {
    _requireNonEmpty(value, fieldName);
  }

  if (result.toSet().length != result.length) {
    throw ArgumentError.value(
      values,
      fieldName,
      'Values must be unique.',
    );
  }

  return List<String>.unmodifiable(result);
}

void _requireNonEmpty(String value, String fieldName) {
  if (value.isEmpty) {
    throw ArgumentError.value(
      value,
      fieldName,
      'Value must not be empty.',
    );
  }
}

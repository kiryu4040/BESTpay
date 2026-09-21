import '../../../core/value_objects/calculation_date.dart';
import '../../../core/value_objects/stable_id.dart';
import 'catalog_entity.dart';
import 'catalog_types.dart';

/// A typed evidence source used by catalog records.
final class CatalogSource implements CatalogEntity {
  CatalogSource({
    required this.id,
    required this.title,
    required this.url,
    required this.publisher,
    required this.sourceType,
    required this.publishedAt,
    required this.lastVerifiedAt,
    required this.accessStatus,
    required this.reliability,
    required Iterable<String> relevantSections,
    required this.summary,
    required this.contentHash,
    required Iterable<String> notes,
  })  : relevantSections = _freezeUniqueText(
          relevantSections,
          'relevantSections',
        ),
        notes = _freezeUniqueText(notes, 'notes') {
    _requireNonEmpty(title, 'title');
    _requireNonEmpty(publisher, 'publisher');

    if (!url.hasScheme) {
      throw ArgumentError.value(
        url,
        'url',
        'URL must be an absolute URI.',
      );
    }

    if (contentHash != null && !_contentHashPattern.hasMatch(contentHash!)) {
      throw ArgumentError.value(
        contentHash,
        'contentHash',
        'Content hash must contain 64 lowercase hexadecimal characters.',
      );
    }
  }

  @override
  final StableId id;
  final String title;
  final Uri url;
  final String publisher;
  final CatalogSourceType sourceType;
  final CalculationDate? publishedAt;
  final CalculationDate lastVerifiedAt;
  final CatalogSourceAccessStatus accessStatus;
  final CatalogSourceReliability reliability;
  final List<String> relevantSections;

  /// May be empty because the schema does not define a minimum length.
  final String summary;

  final String? contentHash;
  final List<String> notes;

  static final RegExp _contentHashPattern = RegExp(r'^[a-f0-9]{64}$');
}

/// A typed mapping between historical and current stable identifiers.
final class IdMigration implements CatalogEntity {
  IdMigration({
    required this.id,
    required this.entityType,
    required this.migrationType,
    required Iterable<StableId> fromIds,
    required Iterable<StableId> toIds,
    required Iterable<StableId> evidenceSourceIds,
    required this.needsReview,
    required this.effectiveFrom,
    required Iterable<String> notes,
  })  : fromIds = _freezeUniqueIds(fromIds, 'fromIds'),
        toIds = _freezeUniqueIds(toIds, 'toIds'),
        evidenceSourceIds = _freezeUniqueIds(
          evidenceSourceIds,
          'evidenceSourceIds',
        ),
        notes = _freezeUniqueText(notes, 'notes') {
    _requireNonEmpty(entityType, 'entityType');
    _validateShape();
  }

  @override
  final StableId id;
  final String entityType;
  final IdMigrationType migrationType;
  final List<StableId> fromIds;
  final List<StableId> toIds;
  final List<StableId> evidenceSourceIds;
  final bool needsReview;
  final CalculationDate effectiveFrom;
  final List<String> notes;

  void _validateShape() {
    switch (migrationType) {
      case IdMigrationType.rename:
        _requireExactCount(fromIds, 1, 'fromIds', migrationType);
        _requireExactCount(toIds, 1, 'toIds', migrationType);
      case IdMigrationType.merge:
        _requireMinimumCount(fromIds, 2, 'fromIds', migrationType);
        _requireExactCount(toIds, 1, 'toIds', migrationType);
      case IdMigrationType.split:
        _requireExactCount(fromIds, 1, 'fromIds', migrationType);
        _requireMinimumCount(toIds, 2, 'toIds', migrationType);
        _requireReview(needsReview, migrationType);
      case IdMigrationType.remove:
        _requireExactCount(fromIds, 1, 'fromIds', migrationType);
        _requireExactCount(toIds, 0, 'toIds', migrationType);
        _requireReview(needsReview, migrationType);
    }
  }
}

void _requireExactCount(
  List<StableId> values,
  int count,
  String fieldName,
  IdMigrationType migrationType,
) {
  if (values.length != count) {
    throw ArgumentError.value(
      values,
      fieldName,
      '${migrationType.value} requires exactly $count value(s).',
    );
  }
}

void _requireMinimumCount(
  List<StableId> values,
  int minimum,
  String fieldName,
  IdMigrationType migrationType,
) {
  if (values.length < minimum) {
    throw ArgumentError.value(
      values,
      fieldName,
      '${migrationType.value} requires at least $minimum value(s).',
    );
  }
}

void _requireReview(
  bool needsReview,
  IdMigrationType migrationType,
) {
  if (!needsReview) {
    throw ArgumentError.value(
      needsReview,
      'needsReview',
      '${migrationType.value} migrations must require review.',
    );
  }
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

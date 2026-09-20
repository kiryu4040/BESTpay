import '../../core/value_objects/catalog_version.dart';

/// One required catalog file declared by the catalog manifest.
final class CatalogManifestItem {
  factory CatalogManifestItem({
    required String fileName,
    required String schemaId,
    required String contentHash,
    required bool isRequired,
  }) {
    final expectedSchemaId = CatalogManifest.expectedSchemaIds[fileName];

    if (expectedSchemaId == null) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'Unknown catalog file name.',
      );
    }

    if (schemaId != expectedSchemaId) {
      throw ArgumentError.value(
        schemaId,
        'schemaId',
        'Schema ID does not match the catalog file name.',
      );
    }

    if (!_contentHashPattern.hasMatch(contentHash)) {
      throw ArgumentError.value(
        contentHash,
        'contentHash',
        'Content hash must be 64 lowercase hexadecimal characters.',
      );
    }

    if (!isRequired) {
      throw ArgumentError.value(
        isRequired,
        'isRequired',
        'Every PR-06 catalog file must be required.',
      );
    }

    return CatalogManifestItem._(
      fileName: fileName,
      schemaId: schemaId,
      contentHash: contentHash,
    );
  }

  const CatalogManifestItem._({
    required this.fileName,
    required this.schemaId,
    required this.contentHash,
  });

  static final RegExp _contentHashPattern = RegExp(r'^[a-f0-9]{64}$');

  final String fileName;
  final String schemaId;
  final String contentHash;

  bool get isRequired => true;
}

/// Validated manifest for the twelve BESTpay v2 catalog files.
final class CatalogManifest {
  factory CatalogManifest({
    required String schemaVersion,
    required CatalogVersion catalogVersion,
    required DateTime generatedAt,
    required Iterable<CatalogManifestItem> items,
  }) {
    if (schemaVersion != '1.0.0') {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'Unsupported catalog manifest schema version.',
      );
    }

    final frozenItems = List<CatalogManifestItem>.unmodifiable(items);

    if (frozenItems.length != expectedSchemaIds.length) {
      throw ArgumentError.value(
        frozenItems.length,
        'items',
        'The manifest must contain exactly twelve catalog files.',
      );
    }

    final itemsByFileName = <String, CatalogManifestItem>{};

    for (final item in frozenItems) {
      if (itemsByFileName.containsKey(item.fileName)) {
        throw ArgumentError.value(
          item.fileName,
          'items',
          'Duplicate catalog file name.',
        );
      }
      itemsByFileName[item.fileName] = item;
    }

    final missingFiles = expectedSchemaIds.keys
        .where((fileName) => !itemsByFileName.containsKey(fileName))
        .toList(growable: false);

    if (missingFiles.isNotEmpty) {
      throw ArgumentError.value(
        missingFiles,
        'items',
        'The manifest is missing required catalog files.',
      );
    }

    return CatalogManifest._(
      schemaVersion: schemaVersion,
      catalogVersion: catalogVersion,
      generatedAt: generatedAt,
      items: frozenItems,
      itemsByFileName: Map<String, CatalogManifestItem>.unmodifiable(
        itemsByFileName,
      ),
    );
  }

  const CatalogManifest._({
    required this.schemaVersion,
    required this.catalogVersion,
    required this.generatedAt,
    required this.items,
    required this.itemsByFileName,
  });

  static const Map<String, String> expectedSchemaIds = <String, String>{
    'payment_instruments.json': 'urn:bestpay:schema:payment-instrument:1.0.0',
    'payment_routes.json': 'urn:bestpay:schema:payment-route:1.0.0',
    'payment_modes.json': 'urn:bestpay:schema:payment-mode:1.0.0',
    'funding_relations.json': 'urn:bestpay:schema:funding-relation:1.0.0',
    'merchant_groups.json': 'urn:bestpay:schema:merchant-group:1.0.0',
    'merchants.json': 'urn:bestpay:schema:merchant:1.0.0',
    'merchant_categories.json': 'urn:bestpay:schema:merchant-category:1.0.0',
    'point_programs.json': 'urn:bestpay:schema:point-program:1.0.0',
    'condition_definitions.json':
        'urn:bestpay:schema:condition-definition:1.0.0',
    'reward_rules.json': 'urn:bestpay:schema:reward-rule:1.0.0',
    'sources.json': 'urn:bestpay:schema:source:1.0.0',
    'id_migrations.json': 'urn:bestpay:schema:id-migration:1.0.0',
  };

  final String schemaVersion;
  final CatalogVersion catalogVersion;
  final DateTime generatedAt;
  final List<CatalogManifestItem> items;
  final Map<String, CatalogManifestItem> itemsByFileName;
}

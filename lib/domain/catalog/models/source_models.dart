import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/catalog/models/catalog_entity.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';

/// A typed evidence source used by catalog records (D-38).
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

    final hash = contentHash;
    if (hash != null && !_contentHashPattern.hasMatch(hash)) {
      throw ArgumentError.value(
        hash,
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

  /// Sections of the source that back the catalog claim.
  final List<String> relevantSections;

  /// May be empty because the schema does not define a minimum length.
  final String summary;

  final String? contentHash;
  final List<String> notes;

  static final RegExp _contentHashPattern = RegExp(r'^[a-f0-9]{64}$');
}

List<String> _freezeUniqueText(Iterable<String> values, String fieldName) {
  final result = List<String>.of(values);

  for (final value in result) {
    _requireNonEmpty(value, fieldName);
  }

  if (result.toSet().length != result.length) {
    throw ArgumentError.value(values, fieldName, 'Values must be unique.');
  }

  return List<String>.unmodifiable(result);
}

void _requireNonEmpty(String value, String fieldName) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, fieldName, 'Value must not be empty.');
  }
}

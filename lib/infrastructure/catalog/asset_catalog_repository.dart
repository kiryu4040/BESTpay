import 'dart:convert';

import 'package:bestpay/application/catalog/catalog_repository.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/infrastructure/catalog/json_catalog_decoder.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Loads the bundled catalog JSON from `assets/data/`.
///
/// Every failure mode — a missing asset, unreadable JSON, an unexpected
/// document shape, or an empty `items` array — resolves to an empty catalog
/// instead of an exception, so startup can never be blocked by catalog data.
final class AssetCatalogRepository
    implements CatalogRepository, CatalogDiagnosticsSource {
  const AssetCatalogRepository({
    AssetBundle? bundle,
    this.dataDirectory = 'assets/data',
  }) : _bundle = bundle;

  final AssetBundle? _bundle;

  /// Directory, relative to the asset root, that holds the catalog files.
  final String dataDirectory;

  /// 直近の [load] で読み込めなかったファイル名（画面に出す診断用）。
  List<String> _missingFileNames = const <String>[];

  @override
  List<String> get missingFileNames => _missingFileNames;

  static const String manifestFileName = 'catalog_manifest.json';

  /// Phase-1 documents that carry real data (the remaining files are empty
  /// placeholders reserved for later phases).
  static const List<String> itemFileNames = <String>[
    'payment_instruments.json',
    'point_programs.json',
    'reward_rules.json',
    'sources.json',
  ];

  @override
  Future<Catalog> load() async {
    try {
      final documents = <String, Map<String, Object?>?>{};
      final missing = <String>[];

      for (final fileName in <String>[manifestFileName, ...itemFileNames]) {
        final document = await _loadDocument(fileName);
        documents[fileName] = document;
        if (document == null || document['items'] is! List) {
          missing.add(fileName);
        }
      }

      _missingFileNames = List<String>.unmodifiable(missing);

      return const JsonCatalogDecoder().decode(
        manifest: documents[manifestFileName],
        paymentInstruments: documents['payment_instruments.json'],
        pointPrograms: documents['point_programs.json'],
        rewardRules: documents['reward_rules.json'],
        sources: documents['sources.json'],
      );
    } catch (_) {
      _missingFileNames = const <String>['（読み込み中に不明なエラー）'];
      return Catalog.empty();
    }
  }

  Future<Map<String, Object?>?> _loadDocument(String fileName) async {
    try {
      final raw = await _bundleOrRootBundle.loadString(
        '$dataDirectory/$fileName',
      );
      final decoded = json.decode(raw);

      if (decoded is! Map) {
        return null;
      }

      final result = <String, Object?>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        if (key is! String) {
          return null;
        }
        result[key] = entry.value;
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  AssetBundle get _bundleOrRootBundle => _bundle ?? rootBundle;
}

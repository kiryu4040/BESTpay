import 'dart:convert';
import 'dart:io';

import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/infrastructure/catalog/json_catalog_decoder.dart';

/// The fixture catalog directory (dummy identifiers only — never real cards).
Directory sampleCatalogDirectory() => Directory('test/fixtures/sample_catalog');

/// Reads one fixture document as a raw JSON object map.
Map<String, Object?> readSampleDocument(String fileName) {
  final file = File('${sampleCatalogDirectory().path}/$fileName');
  final decoded = json.decode(file.readAsStringSync());

  return (decoded as Map<dynamic, dynamic>).cast<String, Object?>();
}

/// Builds the typed fixture catalog through the production decoder.
Catalog loadSampleCatalog() {
  return const JsonCatalogDecoder().decode(
    manifest: readSampleDocument('catalog_manifest.json'),
    paymentInstruments: readSampleDocument('payment_instruments.json'),
    pointPrograms: readSampleDocument('point_programs.json'),
    rewardRules: readSampleDocument('reward_rules.json'),
    sources: readSampleDocument('sources.json'),
  );
}

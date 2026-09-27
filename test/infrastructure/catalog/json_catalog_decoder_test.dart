import 'package:bestpay/infrastructure/catalog/json_catalog_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/sample_catalog_fixture.dart';

void main() {
  group('JsonCatalogDecoder', () {
    test('dummy フィクスチャのカタログを型付きで復号できる', () {
      final catalog = loadSampleCatalog();

      expect(catalog.isNotEmpty, isTrue);
      expect(catalog.paymentInstrumentsById.length, 3);
      expect(catalog.pointProgramsById.length, 2);
      expect(catalog.rewardRulesById.length, 5);
      expect(catalog.sourcesById.length, 1);
      expect(catalog.catalogVersion, '2026.09.27.1');
    });

    test('全ドキュメントが null なら空カタログを返す', () {
      final catalog = const JsonCatalogDecoder().decode();

      expect(catalog.isEmpty, isTrue);
    });

    test('items 配列を持たないドキュメントは空として扱う', () {
      final catalog = const JsonCatalogDecoder().decode(
        paymentInstruments: <String, Object?>{'schemaVersion': '1.0.0'},
      );

      expect(catalog.isEmpty, isTrue);
    });

    test('items が配列でない場合は空として扱う', () {
      final catalog = const JsonCatalogDecoder().decode(
        paymentInstruments: <String, Object?>{'items': 'not a list'},
        rewardRules: <String, Object?>{'items': <String, Object?>{}},
      );

      expect(catalog.isEmpty, isTrue);
    });

    test('壊れたレコードは読み飛ばして全体を失敗させない', () {
      final catalog = const JsonCatalogDecoder().decode(
        paymentInstruments: <String, Object?>{
          'items': <Object?>[
            42,
            'broken',
            <String, Object?>{'id': 'sample_card_a', 'name': 1},
          ],
        },
      );

      expect(catalog.isEmpty, isTrue);
    });

    test('壊れた形の値でも例外を投げない', () {
      final catalog = const JsonCatalogDecoder().decode(
        paymentInstruments: <String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'id': 'sample_card_a',
              'name': 'サンプルカードA',
              'annualFee': 'x',
            },
          ],
        },
        rewardRules: <String, Object?>{
          'items': <Object?>[
            <String, Object?>{'id': 'sample_rule_x', 'calculation': 'nope'},
          ],
        },
        pointPrograms: <String, Object?>{
          'items': <Object?>[
            <String, Object?>{'id': 'sample_point_x', 'valueDefinition': 5},
          ],
        },
        sources: <String, Object?>{
          'items': <Object?>[
            <String, Object?>{'id': 'sample_source_x', 'url': 7},
          ],
        },
      );

      expect(catalog.isEmpty, isTrue);
    });

    test('重複したIDは最初の1件だけを採用する', () {
      final catalog = const JsonCatalogDecoder().decode(
        sources: <String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'id': 'sample_source_official',
              'title': '1件目',
              'url': 'https://example.com/a',
              'publisher': 'サンプル',
              'sourceType': 'officialProductPage',
              'accessStatus': 'accessible',
              'reliability': 'primary',
              'lastVerifiedAt': '2026-09-01',
            },
            <String, Object?>{
              'id': 'sample_source_official',
              'title': '2件目',
              'url': 'https://example.com/b',
              'publisher': 'サンプル',
              'sourceType': 'officialProductPage',
              'accessStatus': 'accessible',
              'reliability': 'primary',
              'lastVerifiedAt': '2026-09-01',
            },
          ],
        },
      );

      expect(catalog.sourcesById.length, 1);
      expect(catalog.sourcesById.values.single.title, '1件目');
    });
  });
}

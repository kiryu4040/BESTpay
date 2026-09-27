import 'package:bestpay/application/catalog/catalog_repository.dart';
import 'package:bestpay/application/merchant/merchant_directory_repository.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/infrastructure/merchant/merchant_directory_decoder.dart';
import 'package:bestpay/ui/ranking_controller.dart';
import 'package:bestpay/ui/screens/merchant_category_screen.dart';
import 'package:bestpay/ui/screens/merchant_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../fixtures/sample_catalog_fixture.dart';

final class _StubCatalogRepository implements CatalogRepository {
  _StubCatalogRepository(this._catalog);

  final Catalog _catalog;

  @override
  Future<Catalog> load() async => _catalog;
}

final class _StubDirectoryRepository implements MerchantDirectoryRepository {
  _StubDirectoryRepository(this._directory);

  final MerchantDirectory _directory;

  @override
  Future<MerchantDirectory> load() async => _directory;
}

Map<String, Object?> _merchantDoc(String id, String name, String category) {
  return <String, Object?>{
    'id': id,
    'name': name,
    'merchantGroupIds': <Object?>['convenience_chain'],
    'categoryIds': <Object?>[category],
    'locationIds': <Object?>[],
    'status': 'active',
    'sourceIds': <Object?>['src_a'],
    'notes': <Object?>['テスト用'],
  };
}

MerchantDirectory _directory() {
  return const MerchantDirectoryDecoder().decode(
    merchants: <String, Object?>{
      'items': <Object?>[
        _merchantDoc('seven_eleven', 'セブン-イレブン', 'convenience_store'),
        _merchantDoc('lawson', 'ローソン', 'convenience_store'),
        _merchantDoc('family_mart', 'ファミリーマート', 'convenience_store'),
        _merchantDoc('ministop', 'ミニストップ', 'convenience_store'),
        _merchantDoc('poplar', 'ポプラ', 'convenience_store'),
        _merchantDoc('mcdonalds', 'マクドナルド', 'fast_food'),
      ],
    },
    merchantCategories: <String, Object?>{
      'items': <Object?>[
        <String, Object?>{
          'id': 'convenience_store',
          'name': 'コンビニ',
          'parentCategoryId': null,
          'status': 'active',
          'sourceIds': <Object?>['src_a'],
          'notes': <Object?>[],
        },
        <String, Object?>{
          'id': 'fast_food',
          'name': 'ファストフード',
          'parentCategoryId': null,
          'status': 'active',
          'sourceIds': <Object?>['src_a'],
          'notes': <Object?>[],
        },
      ],
    },
  );
}

void main() {
  Future<RankingController> pumpScreen(
    WidgetTester tester, {
    Catalog? catalog,
    MerchantDirectory? directory,
  }) async {
    final controller = RankingController(
      repository: _StubCatalogRepository(catalog ?? loadSampleCatalog()),
      directoryRepository: _StubDirectoryRepository(directory ?? _directory()),
    );

    // 縦に長い画面なので、テストでも全体が描画される大きさにする。
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<RankingController>.value(
        value: controller,
        child: const MaterialApp(home: MerchantListScreen()),
      ),
    );

    await controller.loadCatalog();
    await tester.pumpAndSettle();

    return controller;
  }

  testWidgets('タブでは1カテゴリ4店舗までしか出さず、金額の入力欄は無い (D-088, D-093)', (tester) async {
    await pumpScreen(tester);

    expect(find.text('コンビニ'), findsOneWidget);
    expect(find.text('セブン-イレブン'), findsOneWidget);
    expect(find.text('ポプラ'), findsOneWidget);
    expect(find.text('ミニストップ'), findsOneWidget);
    expect(find.text('ファストフード'), findsOneWidget);

    // 5店舗目はタブに出さず「すべて見る」でカテゴリ一覧に送る。
    expect(find.textContaining('すべて見る'), findsOneWidget);
    expect(find.textContaining('今回の支払い金額'), findsNothing);
  });

  testWidgets('カテゴリをタップするとカテゴリだけの一覧に移動し、並べ替えができる', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('コンビニ'));
    await tester.pumpAndSettle();

    expect(find.byType(MerchantCategoryScreen), findsOneWidget);
    expect(find.text('名前順'), findsOneWidget);
    expect(find.text('還元率が高い順'), findsOneWidget);
    expect(find.text('ポプラ'), findsOneWidget);
    expect(find.text('マクドナルド'), findsNothing);

    await tester.tap(find.text('名前順'));
    await tester.pumpAndSettle();

    expect(find.text('ポプラ'), findsOneWidget);
    expect(find.text('ローソン'), findsOneWidget);
    expect(find.text('セブン-イレブン'), findsOneWidget);
  });

  testWidgets('検索で絞り込める', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'セブン');
    await tester.pumpAndSettle();

    expect(find.text('セブン-イレブン'), findsOneWidget);
    expect(find.text('マクドナルド'), findsNothing);
  });

  testWidgets('店舗をタップすると比較が実行される', (tester) async {
    final controller = await pumpScreen(tester);

    await tester.tap(find.text('セブン-イレブン'));
    await tester.pumpAndSettle();

    expect(controller.selectedMerchant?.name, 'セブン-イレブン');
    expect(controller.ranking, isNotNull);
    expect(controller.ranking!.amount.yen, 10000);
  });

  testWidgets('空カタログでは案内を表示する', (tester) async {
    await pumpScreen(tester, catalog: Catalog.empty());

    expect(find.text('カタログはまだ空です'), findsOneWidget);
  });
}

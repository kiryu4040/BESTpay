import 'package:bestpay/application/catalog/catalog_repository.dart';
import 'package:bestpay/application/merchant/merchant_directory_repository.dart';
import 'package:bestpay/application/settings/category_order_store.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/infrastructure/merchant/merchant_directory_decoder.dart';
import 'package:bestpay/ui/ranking_controller.dart';
import 'package:bestpay/ui/screens/card_detail_screen.dart';
import 'package:bestpay/ui/screens/category_order_screen.dart';
import 'package:bestpay/ui/screens/merchant_category_screen.dart';
import 'package:bestpay/ui/screens/merchant_compare_screen.dart';
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
    CategoryOrderStore? orderStore,
  }) async {
    final controller = RankingController(
      repository: _StubCatalogRepository(catalog ?? loadSampleCatalog()),
      directoryRepository: _StubDirectoryRepository(directory ?? _directory()),
      categoryOrderStore: orderStore ?? InMemoryCategoryOrderStore(),
    );

    tester.view.physicalSize = const Size(1000, 2000);
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

  testWidgets('タブは1カテゴリ3店舗までのプレビューで、金額の入力欄は無い (D-088, D-093)', (tester) async {
    await pumpScreen(tester);

    expect(MerchantListScreen.previewLimit, 3);
    expect(find.text('店舗を検索'), findsOneWidget);
    expect(find.text('コンビニ'), findsOneWidget);
    expect(find.textContaining('すべて見る（5店）'), findsOneWidget);
    expect(find.textContaining('今回の支払い金額'), findsNothing);
  });

  testWidgets('検索で絞り込める', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'セブン');
    await tester.pumpAndSettle();

    expect(find.textContaining('セブン'), findsWidgets);
    expect(find.textContaining('マクドナルド'), findsNothing);
  });

  testWidgets('カテゴリの並び順を入れ替えて端末に保存する (D-095)', (tester) async {
    final store = InMemoryCategoryOrderStore();
    final controller = await pumpScreen(tester, orderStore: store);

    final before = controller.orderedCategories
        .map((category) => category.name)
        .toList();
    expect(before, <String>['コンビニ', 'ファストフード']);

    await controller.saveCategoryOrder(
      controller.orderedCategories.reversed.toList(),
    );
    await tester.pumpAndSettle();

    expect(
      controller.orderedCategories.map((category) => category.name).toList(),
      <String>['ファストフード', 'コンビニ'],
    );
    expect(await store.load(), <String>['fast_food', 'convenience_store']);

    final reorderButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.reorder),
        matching: find.byType(IconButton),
      ),
    );
    reorderButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.byType(CategoryOrderScreen), findsOneWidget);
  });

  testWidgets('カテゴリを開くとそのカテゴリの店舗だけが並ぶ (D-093)', (tester) async {
    final controller = await pumpScreen(tester);
    final category = controller.orderedCategories.first;

    await tester.pumpWidget(
      ChangeNotifierProvider<RankingController>.value(
        value: controller,
        child: MaterialApp(home: MerchantCategoryScreen(category: category)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('名前順'), findsOneWidget);
    expect(find.text('還元率が高い順'), findsOneWidget);
    expect(
      controller.directory
          .merchantsInCategory(category.id)
          .every((merchant) => merchant.categoryIds.contains(category.id)),
      isTrue,
    );
    expect(
      controller.directory.merchantsInCategory(category.id).length,
      5,
    );
  });

  testWidgets('店舗を選ぶと比較が実行され、カードはタップで詳細に進める (D-088, D-096)', (tester) async {
    final controller = await pumpScreen(tester);
    final merchant = controller.directory.merchants.first;

    controller.compareAtMerchant(merchant);

    await tester.pumpWidget(
      ChangeNotifierProvider<RankingController>.value(
        value: controller,
        child: MaterialApp(home: MerchantCompareScreen(merchant: merchant)),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.ranking, isNotNull);
    expect(controller.ranking!.amount.yen, 10000);
    expect(find.byType(InkWell), findsWidgets);

    final tile = tester.widget<InkWell>(find.byType(InkWell).first);
    tile.onTap!();
    await tester.pumpAndSettle();

    expect(find.byType(CardDetailScreen), findsOneWidget);
  });

  testWidgets('カード詳細画面はカタログの内容を表示する (D-096)', (tester) async {
    final controller = await pumpScreen(tester);

    await tester.pumpWidget(
      ChangeNotifierProvider<RankingController>.value(
        value: controller,
        child: const MaterialApp(
          home: CardDetailScreen(instrumentId: 'sample_card_b'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('年会費'), findsOneWidget);
    expect(find.text('還元のしくみ'), findsOneWidget);
    expect(find.textContaining('公式情報'), findsOneWidget);
  });

  testWidgets('空カタログでは案内を表示する', (tester) async {
    await pumpScreen(tester, catalog: Catalog.empty());

    expect(find.text('カタログはまだ空です'), findsOneWidget);
  });
}

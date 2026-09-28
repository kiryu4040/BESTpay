import 'package:bestpay/application/catalog/catalog_repository.dart';
import 'package:bestpay/application/merchant/merchant_directory_repository.dart';
import 'package:bestpay/application/settings/condition_options_repository.dart';
import 'package:bestpay/application/settings/user_preferences_store.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/domain/settings/condition_option.dart';
import 'package:bestpay/infrastructure/merchant/merchant_directory_decoder.dart';
import 'package:bestpay/ui/ranking_controller.dart';
import 'package:bestpay/ui/screens/card_detail_screen.dart';
import 'package:bestpay/ui/screens/card_management_screen.dart';
import 'package:bestpay/ui/screens/category_order_screen.dart';
import 'package:bestpay/ui/screens/condition_settings_screen.dart';
import 'package:bestpay/ui/screens/merchant_category_screen.dart';
import 'package:bestpay/ui/screens/merchant_compare_screen.dart';
import 'package:bestpay/ui/screens/merchant_list_screen.dart';
import 'package:bestpay/ui/screens/merchant_order_screen.dart';
import 'package:bestpay/ui/tabs/yearly_tab.dart';
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

final class _StubConditionOptionsRepository
    implements ConditionOptionsRepository {
  @override
  Future<List<ConditionOption>> load() async => const <ConditionOption>[
        ConditionOption(
          id: 'sample_condition',
          name: 'サンプル条件',
          description: 'テスト用の条件です。',
          defaultState: TriState.unknown,
          notes: <String>['テスト用'],
        ),
      ];
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
  Future<RankingController> build(
    WidgetTester tester, {
    Catalog? catalog,
    MerchantDirectory? directory,
    UserPreferencesStore? store,
  }) async {
    final controller = RankingController(
      repository: _StubCatalogRepository(catalog ?? loadSampleCatalog()),
      directoryRepository: _StubDirectoryRepository(directory ?? _directory()),
      conditionOptionsRepository: _StubConditionOptionsRepository(),
      preferencesStore: store ?? InMemoryUserPreferencesStore(),
    );

    await controller.loadCatalog();

    return controller;
  }

  Future<void> pump(
    WidgetTester tester,
    RankingController controller,
    Widget home,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<RankingController>.value(
        value: controller,
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('タブは1カテゴリ3店舗までのプレビューで、金額の入力欄は無い (D-088, D-093)', (tester) async {
    final controller = await build(tester);
    await pump(tester, controller, const MerchantListScreen());

    expect(MerchantListScreen.previewLimit, 3);
    expect(find.text('店舗を検索'), findsOneWidget);
    expect(find.text('コンビニ'), findsOneWidget);
    expect(find.textContaining('すべて見る（5店）'), findsOneWidget);
    expect(find.textContaining('今回の支払い金額'), findsNothing);
  });

  testWidgets('並べ替え後もグリッドの店舗名とアイコンが入れ替わらない (D-098)', (tester) async {
    final controller = await build(tester);
    await pump(tester, controller, const MerchantListScreen());

    final before = controller
        .merchantsInCategoryOrdered(
          controller.orderedCategories.first.id,
        )
        .map((merchant) => merchant.id.value)
        .toList();

    await controller.saveMerchantOrder(
      controller.orderedCategories.first.id,
      controller
          .merchantsInCategoryOrdered(controller.orderedCategories.first.id)
          .reversed
          .toList(),
    );
    await tester.pumpAndSettle();

    final after = controller
        .merchantsInCategoryOrdered(controller.orderedCategories.first.id)
        .map((merchant) => merchant.id.value)
        .toList();

    expect(after, before.reversed.toList());

    // タブには先頭3店舗だけが出る。タイルは店舗IDをキーに持つため、
    // 並べ替えてもアイコンと店舗名が取り違わらない（D-098）。
    for (final id in after.take(MerchantListScreen.previewLimit)) {
      expect(find.byKey(ValueKey<String>('merchant_tile_$id')), findsWidgets);
    }

    final preview = after.take(MerchantListScreen.previewLimit).toList();
    expect(preview.length, MerchantListScreen.previewLimit);
    expect(
      find.byKey(ValueKey<String>('merchant_tile_${preview.first}')),
      findsWidgets,
      reason: '並べ替え後の先頭店舗がタブに出ること',
    );
  });

  testWidgets('カテゴリの並び順を端末に保存する (D-095)', (tester) async {
    final store = InMemoryUserPreferencesStore();
    final controller = await build(tester, store: store);

    await controller.saveCategoryOrder(
      controller.orderedCategories.reversed.toList(),
    );
    await tester.pumpAndSettle();

    expect(
      controller.orderedCategories.map((category) => category.name).toList(),
      <String>['ファストフード', 'コンビニ'],
    );
    expect((await store.load()).categoryOrder,
        <String>['fast_food', 'convenience_store']);
  });

  testWidgets('店舗の並べ替え画面が開き、保存できる (D-099)', (tester) async {
    final store = InMemoryUserPreferencesStore();
    final controller = await build(tester, store: store);
    final category = controller.orderedCategories.first;

    await pump(
      tester,
      controller,
      MerchantOrderScreen(category: category),
    );

    expect(find.textContaining('の並べ替え'), findsWidgets);
    expect(
      find.byType(ReorderableDragStartListener),
      findsWidgets,
    );

    await controller.saveMerchantOrder(
      category.id,
      controller.merchantsInCategoryOrdered(category.id).reversed.toList(),
    );
    await tester.pumpAndSettle();

    expect(
      (await store.load()).merchantOrder[category.id.value],
      isNotNull,
    );
  });

  testWidgets('カテゴリを開くと並べ替えの入口がある (D-093, D-099)', (tester) async {
    final controller = await build(tester);
    final category = controller.orderedCategories.first;

    await pump(tester, controller, MerchantCategoryScreen(category: category));

    expect(find.text('名前順'), findsOneWidget);
    expect(find.text('還元率が高い順'), findsOneWidget);
    expect(find.byIcon(Icons.reorder), findsOneWidget);
    expect(
      controller.directory.merchantsInCategory(category.id).length,
      5,
    );
  });

  testWidgets('比較画面は結論と一覧の両方で券面・名称・還元率を出す (D-103)', (tester) async {
    final controller = await build(tester);
    final merchant = controller.directory.merchants.first;
    controller.compareAtMerchant(merchant);

    await pump(tester, controller, MerchantCompareScreen(merchant: merchant));

    expect(find.textContaining('で支払う'), findsNothing);
    expect(find.textContaining('上回るカードはありません'), findsNothing);
    expect(find.textContaining('還元率'), findsWidgets);
    expect(find.text('タップして詳細'), findsWidgets);
  });

  testWidgets('カード管理でランキング非表示にできる (D-082)', (tester) async {
    final store = InMemoryUserPreferencesStore();
    final controller = await build(tester, store: store);
    await pump(tester, controller, const CardManagementScreen());

    expect(controller.isCardVisible('sample_card_a'), isTrue);

    await controller.setCardVisible('sample_card_a', false);
    await tester.pumpAndSettle();

    expect(controller.isCardVisible('sample_card_a'), isFalse);
    expect((await store.load()).hiddenCardIds, contains('sample_card_a'));

    controller.compareAtMerchant(controller.directory.merchants.first);
    expect(
      controller.ranking!.allEntries
          .any((entry) => entry.instrumentId.value == 'sample_card_a'),
      isFalse,
    );
  });

  testWidgets('条件を設定するとランキングに反映され、端末に保存される (D-101)', (tester) async {
    final store = InMemoryUserPreferencesStore();
    final controller = await build(tester, store: store);
    await pump(tester, controller, const ConditionSettingsScreen());

    expect(find.text('サンプル条件'), findsOneWidget);
    expect(controller.conditionStateOf('sample_condition'), TriState.unknown);

    await controller.setConditionState('sample_condition', TriState.satisfied);
    await tester.pumpAndSettle();

    expect(controller.conditionStateOf('sample_condition'), TriState.satisfied);
    expect((await store.load()).conditionStates['sample_condition'],
        TriState.satisfied);
    expect(controller.conditionContext.states, isNotEmpty);
  });

  testWidgets('年間タブは会計の記録を促す (D-121)', (tester) async {
    final controller = await build(tester);
    await pump(tester, controller, const YearlyTab());

    expect(find.textContaining('会計を記録する'), findsWidgets);
    expect(find.textContaining('1月から12月末までを1年'), findsOneWidget);
  });

  testWidgets('カード詳細から設定へ進める (D-104)', (tester) async {
    final controller = await build(tester);
    await pump(
      tester,
      controller,
      const CardDetailScreen(instrumentId: 'sample_card_b'),
    );

    expect(find.text('カード管理で設定'), findsOneWidget);
    expect(find.text('還元率の基準'), findsOneWidget);
    expect(find.text('還元のしくみ'), findsOneWidget);
  });

  testWidgets('空カタログでは案内を表示する', (tester) async {
    final controller = await build(tester, catalog: Catalog.empty());
    await pump(tester, controller, const MerchantListScreen());

    expect(find.text('カタログはまだ空です'), findsOneWidget);
  });
}

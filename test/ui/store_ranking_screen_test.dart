import 'package:bestpay/application/catalog/catalog_repository.dart';
import 'package:bestpay/application/merchant/merchant_directory_repository.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/infrastructure/merchant/merchant_directory_decoder.dart';
import 'package:bestpay/ui/ranking_controller.dart';
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

/// 実ファイルと同じ形式の店舗データを最小限だけ用意する。
final class _StubDirectoryRepository implements MerchantDirectoryRepository {
  _StubDirectoryRepository(this._directory);

  final MerchantDirectory _directory;

  @override
  Future<MerchantDirectory> load() async => _directory;
}

MerchantDirectory _directory() {
  return const MerchantDirectoryDecoder().decode(
    merchants: <String, Object?>{
      'items': <Object?>[
        <String, Object?>{
          'id': 'seven_eleven',
          'name': 'セブン-イレブン',
          'merchantGroupIds': <Object?>['convenience_chain'],
          'categoryIds': <Object?>['convenience_store'],
          'locationIds': <Object?>[],
          'status': 'active',
          'sourceIds': <Object?>['src_a'],
          'notes': <Object?>['テスト用'],
        },
        <String, Object?>{
          'id': 'other_merchant',
          'name': 'その他の店舗',
          'merchantGroupIds': <Object?>['online_chain'],
          'categoryIds': <Object?>['other_store'],
          'locationIds': <Object?>[],
          'status': 'active',
          'sourceIds': <Object?>['src_a'],
          'notes': <Object?>[],
        },
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
          'id': 'other_store',
          'name': 'その他（得意店舗なし）',
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

  testWidgets('店舗が一覧表示され、金額の入力欄は無い (D-088)', (tester) async {
    await pumpScreen(tester);

    expect(find.text('セブン-イレブン'), findsOneWidget);
    expect(find.text('コンビニ'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('店舗を検索'), findsOneWidget);
    expect(find.textContaining('今回の支払い金額'), findsNothing);
  });

  testWidgets('検索で絞り込める', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'セブン');
    await tester.pumpAndSettle();

    expect(find.text('セブン-イレブン'), findsOneWidget);
    expect(find.text('その他の店舗'), findsNothing);
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

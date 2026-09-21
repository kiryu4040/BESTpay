import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/merchant_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Merchant', () {
    test('stores typed references and defensively copies lists', () {
      final groupIds = <StableId>[_id('group_one')];
      final categoryIds = <StableId>[_id('category_one')];
      final locationIds = <StableId>[_id('location_one')];
      final sourceIds = <StableId>[_id('source_one')];
      final notes = <String>['verified'];

      final merchant = Merchant(
        id: _id('merchant_one'),
        name: 'Merchant One',
        merchantGroupIds: groupIds,
        categoryIds: categoryIds,
        locationIds: locationIds,
        status: CatalogItemStatus.active,
        sourceIds: sourceIds,
        notes: notes,
      );

      groupIds.add(_id('group_two'));
      categoryIds.add(_id('category_two'));
      locationIds.add(_id('location_two'));
      sourceIds.add(_id('source_two'));
      notes.add('changed');

      expect(merchant.merchantGroupIds, <StableId>[_id('group_one')]);
      expect(merchant.categoryIds, <StableId>[_id('category_one')]);
      expect(merchant.locationIds, <StableId>[_id('location_one')]);
      expect(merchant.sourceIds, <StableId>[_id('source_one')]);
      expect(merchant.notes, <String>['verified']);

      expect(
        () => merchant.categoryIds.add(_id('category_three')),
        throwsUnsupportedError,
      );
    });

    test('allows empty selector lists', () {
      final merchant = Merchant(
        id: _id('merchant_one'),
        name: 'Merchant One',
        merchantGroupIds: const <StableId>[],
        categoryIds: const <StableId>[],
        locationIds: const <StableId>[],
        status: CatalogItemStatus.draft,
        sourceIds: const <StableId>[],
        notes: const <String>[],
      );

      expect(merchant.merchantGroupIds, isEmpty);
      expect(merchant.categoryIds, isEmpty);
      expect(merchant.locationIds, isEmpty);
    });

    test('rejects blank names and duplicate set values', () {
      expect(
        () => Merchant(
          id: _id('merchant_one'),
          name: '',
          merchantGroupIds: const <StableId>[],
          categoryIds: const <StableId>[],
          locationIds: const <StableId>[],
          status: CatalogItemStatus.active,
          sourceIds: const <StableId>[],
          notes: const <String>[],
        ),
        throwsArgumentError,
      );

      final categoryId = _id('category_one');

      expect(
        () => Merchant(
          id: _id('merchant_one'),
          name: 'Merchant One',
          merchantGroupIds: const <StableId>[],
          categoryIds: <StableId>[categoryId, categoryId],
          locationIds: const <StableId>[],
          status: CatalogItemStatus.active,
          sourceIds: const <StableId>[],
          notes: const <String>[],
        ),
        throwsArgumentError,
      );
    });
  });

  group('MerchantGroup', () {
    test('allows an empty description as permitted by the schema', () {
      final sourceIds = <StableId>[_id('source_one')];

      final group = MerchantGroup(
        id: _id('group_one'),
        name: 'Group One',
        description: '',
        status: CatalogItemStatus.active,
        sourceIds: sourceIds,
        notes: const <String>[],
      );

      sourceIds.add(_id('source_two'));

      expect(group.description, isEmpty);
      expect(group.sourceIds, <StableId>[_id('source_one')]);
    });

    test('rejects blank name and duplicate notes', () {
      expect(
        () => MerchantGroup(
          id: _id('group_one'),
          name: '',
          description: '',
          status: CatalogItemStatus.active,
          sourceIds: const <StableId>[],
          notes: const <String>[],
        ),
        throwsArgumentError,
      );

      expect(
        () => MerchantGroup(
          id: _id('group_one'),
          name: 'Group One',
          description: '',
          status: CatalogItemStatus.active,
          sourceIds: const <StableId>[],
          notes: const <String>['note', 'note'],
        ),
        throwsArgumentError,
      );
    });
  });

  group('MerchantCategory', () {
    test('supports a null parent for a root category', () {
      final category = MerchantCategory(
        id: _id('category_one'),
        name: 'Category One',
        parentCategoryId: null,
        status: CatalogItemStatus.active,
        sourceIds: const <StableId>[],
        notes: const <String>[],
      );

      expect(category.parentCategoryId, isNull);
    });

    test('stores a typed parent category reference', () {
      final category = MerchantCategory(
        id: _id('category_child'),
        name: 'Child',
        parentCategoryId: _id('category_parent'),
        status: CatalogItemStatus.active,
        sourceIds: const <StableId>[],
        notes: const <String>[],
      );

      expect(category.parentCategoryId, _id('category_parent'));
    });

    test('freezes source and note collections', () {
      final sourceIds = <StableId>[_id('source_one')];
      final notes = <String>['note'];

      final category = MerchantCategory(
        id: _id('category_one'),
        name: 'Category One',
        parentCategoryId: null,
        status: CatalogItemStatus.active,
        sourceIds: sourceIds,
        notes: notes,
      );

      sourceIds.add(_id('source_two'));
      notes.add('changed');

      expect(category.sourceIds, <StableId>[_id('source_one')]);
      expect(category.notes, <String>['note']);
      expect(
        () => category.notes.add('new'),
        throwsUnsupportedError,
      );
    });
  });
}

StableId _id(String value) {
  final result = StableId.create(value);
  expect(result, isA<AppSuccess<StableId>>());
  return (result as AppSuccess<StableId>).value;
}

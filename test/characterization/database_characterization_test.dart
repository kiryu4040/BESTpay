import 'dart:io';

import 'package:bestpay/db/database_helper.dart';
import 'package:bestpay/models/reward_rule.dart';
import 'package:bestpay/models/user_condition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporaryDirectory;
  late Database database;
  final helper = DatabaseHelper.instance;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    temporaryDirectory =
        await Directory.systemTemp.createTemp('bestpay_characterization_');

    await databaseFactory.setDatabasesPath(temporaryDirectory.path);
    database = await helper.database;
  });

  setUp(() async {
    await database.delete('user_conditions');
    await database.delete('custom_rules');
    await database.update('payment_methods', {'enabled': 1});
    await database.update('stores', {'is_favorite': 0});
  });

  tearDownAll(() async {
    await database.close();

    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  group('Database schema legacy characterization', () {
    test('opens the current database at version 1', () async {
      expect(await database.getVersion(), 1);
    });

    test('creates the current six application tables', () async {
      final rows = await database.rawQuery(
        '''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
          AND name NOT LIKE 'sqlite_%'
        ORDER BY name
        ''',
      );

      final names = rows.map((row) => row['name']).toList();

      expect(
        names,
        <Object?>[
          'custom_rules',
          'payment_methods',
          'reward_rules',
          'stores',
          'usage_history',
          'user_conditions',
        ],
      );
    });

    test('creates the current two named indexes', () async {
      final rows = await database.rawQuery(
        '''
        SELECT name
        FROM sqlite_master
        WHERE type = 'index'
        ORDER BY name
        ''',
      );

      final names = rows.map((row) => row['name']).toList();

      expect(names, contains('idx_reward_store'));
      expect(names, contains('idx_stores_cat'));
    });

    test('does not enable SQLite foreign key enforcement', () async {
      final rows = await database.rawQuery('PRAGMA foreign_keys');

      expect(rows.single['foreign_keys'], 0);
    });
  });

  group('Seed data legacy characterization', () {
    test('creates nine payment methods and fifty-eight stores', () async {
      final paymentCount = Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM payment_methods'),
      );
      final storeCount = Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM stores'),
      );
      final ruleCount = Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM reward_rules'),
      );

      expect(paymentCount, 9);
      expect(storeCount, 58);
      expect(ruleCount, isNotNull);
      expect(ruleCount, greaterThan(0));
    });

    test('keeps the current fixed payment ID ordering', () async {
      final payments = await helper.getPaymentMethods();

      expect(payments, hasLength(9));
      expect(payments[0].id, 1);
      expect(payments[0].name, 'Oliveフレキシブルペイ ゴールド');
      expect(payments[1].id, 2);
      expect(payments[1].name, '三井住友カード ゴールド(NL)');
      expect(payments[2].id, 3);
      expect(payments[2].name, 'V NEOBANK デビット');
      expect(payments[8].id, 9);
      expect(payments[8].name, 'メルカード');
    });
  });

  group('DatabaseHelper legacy characterization', () {
    test('onlyEnabled excludes a disabled payment', () async {
      await helper.updatePaymentEnabled(1, false);

      final all = await helper.getPaymentMethods();
      final enabled = await helper.getPaymentMethods(onlyEnabled: true);

      expect(all, hasLength(9));
      expect(enabled, hasLength(8));
      expect(enabled.any((payment) => payment.id == 1), isFalse);
    });

    test('returns merged default conditions when the table is empty', () async {
      final storedRows = await database.query('user_conditions');
      final conditions = await helper.getConditions();

      expect(storedRows, isEmpty);
      expect(conditions, hasLength(22));
      expect(conditions[UserConditionKeys.oliveAccount], 'none');
      expect(conditions[UserConditionKeys.sbiSecurities], '0');
    });

    test('stores and replaces a user condition', () async {
      await helper.setCondition(UserConditionKeys.sbiSecurities, '1');
      await helper.setCondition(UserConditionKeys.sbiSecurities, '0');

      final rows = await database.query(
        'user_conditions',
        where: 'key = ?',
        whereArgs: [UserConditionKeys.sbiSecurities],
      );
      final conditions = await helper.getConditions();

      expect(rows, hasLength(1));
      expect(conditions[UserConditionKeys.sbiSecurities], '0');
    });

    test('searches stores using aliases', () async {
      final stores = await helper.searchStores('711');

      expect(stores, isNotEmpty);
      expect(stores.any((store) => store.name == 'セブン-イレブン'), isTrue);
    });

    test('stores and retrieves a favorite flag', () async {
      await helper.toggleFavorite(1, true);

      final favorites = await helper.getStores(favorite: true);

      expect(favorites.any((store) => store.id == 1), isTrue);
    });

    test('inserts, retrieves, and deletes a custom rule', () async {
      final id = await helper.insertCustomRule(
        CustomRule(
          storeId: 1,
          paymentId: 1,
          customRate: 3.25,
          memo: 'characterization',
          createdAt: '2026-09-14T00:00:00Z',
        ),
      );

      final inserted = await helper.getCustomRules();

      expect(inserted, hasLength(1));
      expect(inserted.single.id, id);
      expect(inserted.single.storeId, 1);
      expect(inserted.single.paymentId, 1);
      expect(inserted.single.customRate, 3.25);
      expect(inserted.single.memo, 'characterization');

      expect(await helper.deleteCustomRule(id), 1);
      expect(await helper.getCustomRules(), isEmpty);
    });

    test('exports the current version 1 backup shape', () async {
      await helper.setCondition(UserConditionKeys.sbiSecurities, '1');

      final exported = await helper.exportAll();

      expect(exported['version'], 1);
      expect(exported['exported_at'], isA<String>());
      expect(exported['payment_methods'], isA<List<dynamic>>());
      expect(exported['stores'], isA<List<dynamic>>());
      expect(exported['reward_rules'], isA<List<dynamic>>());
      expect(exported['custom_rules'], isA<List<dynamic>>());
      expect(exported['user_conditions'], isA<List<dynamic>>());

      expect(exported.containsKey('usage_history'), isFalse);
      expect(exported.containsKey('themeMode'), isFalse);
      expect(exported.containsKey('schemaVersion'), isFalse);
      expect(exported.containsKey('formatId'), isFalse);
    });

    test('empty import deletes conditions and custom rules', () async {
      await helper.setCondition(UserConditionKeys.sbiSecurities, '1');

      await helper.insertCustomRule(
        CustomRule(
          storeId: 1,
          paymentId: 1,
          customRate: 3.25,
          memo: 'will be deleted',
          createdAt: '2026-09-14T00:00:00Z',
        ),
      );

      await helper.importAll(<String, dynamic>{});

      final conditionRows = await database.query('user_conditions');
      final customRuleRows = await database.query('custom_rules');

      expect(conditionRows, isEmpty);
      expect(customRuleRows, isEmpty);
    });
  });
}

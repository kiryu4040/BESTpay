import 'dart:io';

import 'package:bestpay/db/database_helper.dart';
import 'package:bestpay/models/user_condition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporaryDirectory;
  late Database database;
  final helper = DatabaseHelper.instance;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    temporaryDirectory =
        await Directory.systemTemp.createTemp('bestpay_backup_restore_');

    await databaseFactory.setDatabasesPath(temporaryDirectory.path);
    database = await helper.database;
  });

  setUp(() async {
    await database.delete('user_conditions');
    await database.delete('custom_rules');
    await database.delete('usage_history');
    await database.update('payment_methods', {'enabled': 1});
    await database.update('stores', {'is_favorite': 0});
  });

  tearDownAll(() async {
    await database.close();

    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  group('Legacy backup restore characterization', () {
    test('restores user conditions and replaces existing rows', () async {
      await helper.setCondition(UserConditionKeys.sbiSecurities, '0');
      await helper.setCondition(UserConditionKeys.familyPoints, '3');

      await helper.importAll(
        <String, dynamic>{
          'version': 1,
          'user_conditions': <Map<String, Object?>>[
            <String, Object?>{
              'key': UserConditionKeys.sbiSecurities,
              'value': '1',
            },
          ],
        },
      );

      final storedRows = await database.query(
        'user_conditions',
        orderBy: 'key',
      );
      final conditions = await helper.getConditions();

      expect(storedRows, hasLength(1));
      expect(conditions[UserConditionKeys.sbiSecurities], '1');
      expect(conditions[UserConditionKeys.familyPoints], '0');
    });

    test('restores custom rules but does not preserve imported IDs', () async {
      await helper.importAll(
        <String, dynamic>{
          'version': 1,
          'custom_rules': <Map<String, Object?>>[
            <String, Object?>{
              'id': 999,
              'store_id': 1,
              'payment_id': 2,
              'custom_rate': 3.25,
              'memo': 'restored custom rule',
              'created_at': '2026-09-14T00:00:00Z',
            },
          ],
        },
      );

      final rules = await helper.getCustomRules();

      expect(rules, hasLength(1));
      expect(rules.single.id, isNot(999));
      expect(rules.single.storeId, 1);
      expect(rules.single.paymentId, 2);
      expect(rules.single.customRate, 3.25);
      expect(rules.single.memo, 'restored custom rule');
    });

    test('partially restores mutable payment method fields', () async {
      final before = await helper.getPayment(1);

      await helper.importAll(
        <String, dynamic>{
          'version': 1,
          'payment_methods': <Map<String, Object?>>[
            <String, Object?>{
              'id': 1,
              'name': 'Ignored imported name',
              'base_rate': 99.0,
              'enabled': 0,
              'note': 'Imported note',
              'color': '#ABCDEF',
            },
          ],
        },
      );

      final after = await helper.getPayment(1);

      expect(before, isNotNull);
      expect(after, isNotNull);
      expect(after!.name, before!.name);
      expect(after.baseRate, before.baseRate);
      expect(after.enabled, isFalse);
      expect(after.note, 'Imported note');
      expect(after.color, '#ABCDEF');
    });

    test('partially restores the store favorite flag', () async {
      await helper.importAll(
        <String, dynamic>{
          'version': 1,
          'stores': <Map<String, Object?>>[
            <String, Object?>{
              'id': 1,
              'name': 'Ignored imported store name',
              'is_favorite': 1,
            },
          ],
        },
      );

      final favorites = await helper.getStores(favorite: true);

      expect(favorites, hasLength(1));
      expect(favorites.single.id, 1);
      expect(favorites.single.name, 'セブン-イレブン');
    });

    test('currently ignores an unsupported backup version', () async {
      await helper.importAll(
        <String, dynamic>{
          'version': 999,
          'user_conditions': <Map<String, Object?>>[
            <String, Object?>{
              'key': UserConditionKeys.sbiSecurities,
              'value': '1',
            },
          ],
        },
      );

      final conditions = await helper.getConditions();

      expect(conditions[UserConditionKeys.sbiSecurities], '1');
    });

    test('does not restore reward rules from the backup payload', () async {
      final before = (await database.query(
        'reward_rules',
        where: 'id = ?',
        whereArgs: <Object?>[1],
      ))
          .single;

      await helper.importAll(
        <String, dynamic>{
          'version': 1,
          'reward_rules': <Map<String, Object?>>[
            <String, Object?>{
              'id': 1,
              'store_id': 999,
              'payment_id': 999,
              'base_bonus': 999.0,
              'max_bonus': 999.0,
              'condition_key': 'imported',
              'note': 'must be ignored',
            },
          ],
        },
      );

      final after = (await database.query(
        'reward_rules',
        where: 'id = ?',
        whereArgs: <Object?>[1],
      ))
          .single;

      expect(after, before);
    });

    test('does not restore usage history from the backup payload', () async {
      await helper.importAll(
        <String, dynamic>{
          'version': 1,
          'usage_history': <Map<String, Object?>>[
            <String, Object?>{
              'id': 1,
              'date': '2026-09-14',
              'store_id': 1,
              'payment_id': 1,
              'amount': 1000,
              'reward_earned': 10.0,
            },
          ],
        },
      );

      final rows = await database.query('usage_history');

      expect(rows, isEmpty);
    });

    test('does not apply a batch when a row has an invalid type', () async {
      await helper.setCondition(UserConditionKeys.sbiSecurities, '1');

      await expectLater(
        helper.importAll(
          <String, dynamic>{
            'version': 1,
            'user_conditions': <Object?>[
              <String, Object?>{
                'key': UserConditionKeys.sbiSecurities,
                'value': '0',
              },
              'invalid row',
            ],
          },
        ),
        throwsA(isA<TypeError>()),
      );

      final rows = await database.query(
        'user_conditions',
        where: 'key = ?',
        whereArgs: <Object?>[UserConditionKeys.sbiSecurities],
      );

      expect(rows, hasLength(1));
      expect(rows.single['value'], '1');
    });
  });
}

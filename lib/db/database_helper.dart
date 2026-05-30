import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/payment_method.dart';
import '../models/reward_rule.dart';
import '../models/store.dart';
import '../models/user_condition.dart';
import 'database_initializer.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'bestpay.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int v) async {
    await db.execute('''
      CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT,
        issuer TEXT,
        base_rate REAL,
        annual_fee INTEGER,
        enabled INTEGER DEFAULT 1,
        color TEXT,
        note TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE stores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT,
        aliases TEXT,
        icon TEXT,
        is_favorite INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE reward_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id INTEGER,
        payment_id INTEGER,
        base_bonus REAL,
        max_bonus REAL,
        condition_key TEXT,
        note TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE user_conditions (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE custom_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id INTEGER,
        payment_id INTEGER,
        custom_rate REAL,
        memo TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE usage_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        store_id INTEGER,
        payment_id INTEGER,
        amount INTEGER,
        reward_earned REAL
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_reward_store ON reward_rules(store_id, payment_id)');
    await db.execute('CREATE INDEX idx_stores_cat ON stores(category)');

    await DatabaseInitializer.seed(db);
  }

  Future<List<PaymentMethod>> getPaymentMethods(
      {bool onlyEnabled = false}) async {
    final db = await database;
    final maps = await db.query(
      'payment_methods',
      where: onlyEnabled ? 'enabled = 1' : null,
      orderBy: 'id ASC',
    );
    return maps.map(PaymentMethod.fromMap).toList();
  }

  Future<PaymentMethod?> getPayment(int id) async {
    final db = await database;
    final r =
        await db.query('payment_methods', where: 'id=?', whereArgs: [id]);
    if (r.isEmpty) return null;
    return PaymentMethod.fromMap(r.first);
  }

  Future<int> updatePaymentEnabled(int id, bool enabled) async {
    final db = await database;
    return db.update('payment_methods', {'enabled': enabled ? 1 : 0},
        where: 'id=?', whereArgs: [id]);
  }

  Future<int> insertPayment(PaymentMethod p) async {
    final db = await database;
    return db.insert('payment_methods', p.toMap()..remove('id'));
  }

  Future<int> updatePayment(PaymentMethod p) async {
    final db = await database;
    return db.update('payment_methods', p.toMap(),
        where: 'id=?', whereArgs: [p.id]);
  }

  Future<List<Store>> getStores({String? category, bool? favorite}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (category != null) {
      where.add('category=?');
      args.add(category);
    }
    if (favorite == true) where.add('is_favorite=1');
    final maps = await db.query(
      'stores',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'is_favorite DESC, name ASC',
    );
    return maps.map(Store.fromMap).toList();
  }

  Future<List<Store>> searchStores(String keyword) async {
    final db = await database;
    final k = '%$keyword%';
    final maps = await db.query(
      'stores',
      where: 'name LIKE ? OR aliases LIKE ?',
      whereArgs: [k, k],
      orderBy: 'is_favorite DESC, name ASC',
      limit: 50,
    );
    return maps.map(Store.fromMap).toList();
  }

  Future<Store?> getStore(int id) async {
    final db = await database;
    final r = await db.query('stores', where: 'id=?', whereArgs: [id]);
    if (r.isEmpty) return null;
    return Store.fromMap(r.first);
  }

  Future<int> toggleFavorite(int id, bool fav) async {
    final db = await database;
    return db.update('stores', {'is_favorite': fav ? 1 : 0},
        where: 'id=?', whereArgs: [id]);
  }

  Future<int> insertStore(Store s) async {
    final db = await database;
    return db.insert('stores', s.toMap()..remove('id'));
  }

  Future<List<RewardRule>> getRulesForStore(int storeId) async {
    final db = await database;
    final maps = await db
        .query('reward_rules', where: 'store_id=?', whereArgs: [storeId]);
    return maps.map(RewardRule.fromMap).toList();
  }

  Future<List<CustomRule>> getCustomRules() async {
    final db = await database;
    final maps = await db.query('custom_rules', orderBy: 'created_at DESC');
    return maps.map(CustomRule.fromMap).toList();
  }

  Future<int> insertCustomRule(CustomRule c) async {
    final db = await database;
    return db.insert('custom_rules', c.toMap()..remove('id'));
  }

  Future<int> deleteCustomRule(int id) async {
    final db = await database;
    return db.delete('custom_rules', where: 'id=?', whereArgs: [id]);
  }

  Future<Map<String, String>> getConditions() async {
    final db = await database;
    final result = <String, String>{...UserConditionKeys.defaults()};
    final rows = await db.query('user_conditions');
    for (final r in rows) {
      result[r['key'] as String] = (r['value'] as String?) ?? '0';
    }
    return result;
  }

  Future<void> setCondition(String key, String value) async {
    final db = await database;
    await db.insert(
      'user_conditions',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setConditions(Map<String, String> map) async {
    final db = await database;
    final batch = db.batch();
    for (final e in map.entries) {
      batch.insert(
        'user_conditions',
        {'key': e.key, 'value': e.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<String>> getCategories() async {
    final db = await database;
    final rows = await db
        .rawQuery('SELECT DISTINCT category FROM stores ORDER BY category');
    return rows.map((r) => r['category'] as String).toList();
  }

  Future<Map<String, dynamic>> exportAll() async {
    final db = await database;
    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'payment_methods': await db.query('payment_methods'),
      'stores': await db.query('stores'),
      'reward_rules': await db.query('reward_rules'),
      'custom_rules': await db.query('custom_rules'),
      'user_conditions': await db.query('user_conditions'),
    };
  }

  Future<void> importAll(Map<String, dynamic> json) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('user_conditions');
    batch.delete('custom_rules');
    for (final r in (json['user_conditions'] as List? ?? [])) {
      batch.insert('user_conditions', Map<String, Object?>.from(r as Map));
    }
    for (final r in (json['custom_rules'] as List? ?? [])) {
      final m = Map<String, Object?>.from(r as Map)..remove('id');
      batch.insert('custom_rules', m);
    }
    for (final r in (json['payment_methods'] as List? ?? [])) {
      final m = Map<String, Object?>.from(r as Map);
      if (m['id'] != null) {
        batch.update(
          'payment_methods',
          {
            'enabled': m['enabled'] ?? 1,
            'note': m['note'] ?? '',
            'color': m['color'] ?? '#1976D2',
          },
          where: 'id=?',
          whereArgs: [m['id']],
        );
      }
    }
    for (final r in (json['stores'] as List? ?? [])) {
      final m = Map<String, Object?>.from(r as Map);
      if (m['id'] != null) {
        batch.update(
          'stores',
          {'is_favorite': m['is_favorite'] ?? 0},
          where: 'id=?',
          whereArgs: [m['id']],
        );
      }
    }
    await batch.commit(noResult: true);
  }
}

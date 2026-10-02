import 'dart:convert';

import 'package:bestpay/application/records/transaction_record_store.dart';
import 'package:bestpay/domain/records/transaction_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端末に会計記録を保存する（D-121）。
///
/// 壊れた値や読み取り失敗は空に落とし、起動を止めない。
final class SharedPreferencesTransactionRecordStore
    implements TransactionRecordStore {
  const SharedPreferencesTransactionRecordStore();

  static const String _key = 'transaction_records_v1';

  @override
  Future<List<TransactionRecord>> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getStringList(_key);
      if (raw == null) {
        return const <TransactionRecord>[];
      }

      // 壊れた1行があっても、残りの記録は読み込む（D-168）。
      // 以前は1行の失敗で全件が空になっていた。
      final records = <TransactionRecord>[];
      for (final line in raw) {
        try {
          final decoded = json.decode(line);
          if (decoded is! Map) {
            continue;
          }

          final record = TransactionRecord.fromJson(
            decoded.cast<String, Object?>(),
          );
          if (record != null) {
            records.add(record);
          }
        } on Object {
          continue;
        }
      }

      return List<TransactionRecord>.unmodifiable(records);
    } on Object {
      return const <TransactionRecord>[];
    }
  }

  @override
  Future<void> save(List<TransactionRecord> records) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        _key,
        <String>[
          for (final record in records) json.encode(record.toJson()),
        ],
      );
    } on Object {
      // 保存できなくても操作は続けられる。
    }
  }
}

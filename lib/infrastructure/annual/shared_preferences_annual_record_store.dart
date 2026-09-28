import 'dart:convert';

import 'package:bestpay/application/annual/annual_record_store.dart';
import 'package:bestpay/domain/annual/annual_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 会計の記録を端末の保存領域に置く（D-122）。
///
/// 壊れた1件は捨て、残りは読む。読み書きに失敗しても起動は止めない。
final class SharedPreferencesAnnualRecordStore implements AnnualRecordStore {
  const SharedPreferencesAnnualRecordStore();

  static const String _key = 'annual_records_v1';

  @override
  Future<List<AnnualRecord>> load() async {
    try {
      final store = await SharedPreferences.getInstance();
      final raw = store.getStringList(_key);
      if (raw == null) {
        return const <AnnualRecord>[];
      }

      final records = <AnnualRecord>[];
      for (final text in raw) {
        try {
          final decoded = json.decode(text);
          if (decoded is! Map) {
            continue;
          }

          final record = AnnualRecord.fromJson(
            decoded.cast<String, Object?>(),
          );
          if (record != null) {
            records.add(record);
          }
        } on Object {
          continue;
        }
      }

      records.sort((left, right) => right.date.compareTo(left.date));
      return List<AnnualRecord>.unmodifiable(records);
    } on Object {
      return const <AnnualRecord>[];
    }
  }

  @override
  Future<void> save(List<AnnualRecord> records) async {
    try {
      final store = await SharedPreferences.getInstance();
      await store.setStringList(
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

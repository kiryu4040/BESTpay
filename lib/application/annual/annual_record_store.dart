import 'package:bestpay/domain/annual/annual_record.dart';

/// 会計の記録を端末に保存する（D-122）。
abstract interface class AnnualRecordStore {
  Future<List<AnnualRecord>> load();

  Future<void> save(List<AnnualRecord> records);
}

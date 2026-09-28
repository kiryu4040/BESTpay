import 'package:bestpay/domain/records/transaction_record.dart';

/// 会計記録の保存先（D-121）。
abstract interface class TransactionRecordStore {
  Future<List<TransactionRecord>> load();

  Future<void> save(List<TransactionRecord> records);
}

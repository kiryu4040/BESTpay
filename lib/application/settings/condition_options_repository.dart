import 'package:bestpay/domain/settings/condition_option.dart';

/// 条件定義の読み込み口（D-101）。
abstract interface class ConditionOptionsRepository {
  Future<List<ConditionOption>> load();
}

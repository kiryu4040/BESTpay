import 'package:bestpay/domain/merchant/merchant_directory.dart';

/// 店舗一覧の読み込み口。UI はこの契約だけを知る（D-60）。
abstract interface class MerchantDirectoryRepository {
  Future<MerchantDirectory> load();
}

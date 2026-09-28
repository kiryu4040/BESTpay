import 'package:bestpay/core/value_objects/calculation_date.dart';

/// 会計1件の記録（D-122）。
///
/// 年間タブで「いつ・どの店で・いくら使ったか」を1件ずつ残す。
final class AnnualRecord {
  const AnnualRecord({
    required this.id,
    required this.date,
    required this.merchantId,
    required this.merchantName,
    required this.amountYen,
  });

  final String id;
  final CalculationDate date;
  final String merchantId;
  final String merchantName;
  final int amountYen;

  int get year => date.year;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'date': date.toString(),
      'merchantId': merchantId,
      'merchantName': merchantName,
      'amountYen': amountYen,
    };
  }

  static AnnualRecord? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final merchantId = json['merchantId'];
    final amount = json['amountYen'];
    if (id is! String || merchantId is! String || amount is! int) {
      return null;
    }

    final date = CalculationDate.parse(json['date'] is String
        ? json['date']! as String
        : '');
    return date.fold(
      onSuccess: (value) => AnnualRecord(
        id: id,
        date: value,
        merchantId: merchantId,
        merchantName: json['merchantName'] is String
            ? json['merchantName']! as String
            : merchantId,
        amountYen: amount,
      ),
      onFailure: (_) => null,
    );
  }
}

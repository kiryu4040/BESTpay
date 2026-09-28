/// 会計1件の記録（D-121）。
///
/// 年間タブで「いつ・どの店で・いくら使ったか」を残すための最小の情報。
/// 還元額は保存せず、そのつどカタログから計算し直す。
final class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.occurredOn,
    required this.merchantId,
    required this.merchantName,
    required this.instrumentId,
    required this.amountYen,
  });

  /// 端末内で一意なID。
  final String id;

  /// 会計日（`yyyy-MM-dd`）。
  final String occurredOn;

  final String merchantId;
  final String merchantName;
  final String instrumentId;
  final int amountYen;

  /// 会計日の年（1月から12月末までを1年として数える）。
  int get year => int.tryParse(occurredOn.split('-').first) ?? 0;

  /// 会計日の月。
  int get month {
    final parts = occurredOn.split('-');
    if (parts.length < 2) {
      return 0;
    }

    return int.tryParse(parts[1]) ?? 0;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'on': occurredOn,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'instrumentId': instrumentId,
      'amountYen': amountYen,
    };
  }

  /// 壊れた行は捨てる（null を返す）。
  static TransactionRecord? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final on = json['on'];
    final merchantId = json['merchantId'];
    final instrumentId = json['instrumentId'];
    final amount = json['amountYen'];

    if (id is! String || on is! String || merchantId is! String) {
      return null;
    }

    if (instrumentId is! String || amount is! int || amount < 0) {
      return null;
    }

    if (on.length != 10) {
      return null;
    }

    final name = json['merchantName'];

    return TransactionRecord(
      id: id,
      occurredOn: on,
      merchantId: merchantId,
      merchantName: name is String ? name : merchantId,
      instrumentId: instrumentId,
      amountYen: amount,
    );
  }
}

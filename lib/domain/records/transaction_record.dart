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

  /// カードが特定できない記録の既定カード（基準カード・D-084）。
  static const String fallbackInstrumentId = 'mizuho_rakuten_card';

  /// 壊れた行は捨てる（null を返す）。
  ///
  /// 古い形式（カードや店舗の項目が無い）の記録も読めるように、
  /// 欠けた項目は既定値で補う（D-168）。読み込みで一部の記録が
  /// 消えてしまうのを防ぐ。
  static TransactionRecord? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final on = json['on'];

    if (id is! String || id.isEmpty || on is! String || on.length != 10) {
      return null;
    }

    final rawAmount = json['amountYen'];
    final amount = rawAmount is int
        ? rawAmount
        : rawAmount is num
            ? rawAmount.toInt()
            : rawAmount is String
                ? int.tryParse(rawAmount)
                : null;
    if (amount == null || amount < 0) {
      return null;
    }

    final merchantId = json['merchantId'];
    final instrumentId = json['instrumentId'];
    final name = json['merchantName'];
    final merchant = merchantId is String ? merchantId : '';

    return TransactionRecord(
      id: id,
      occurredOn: on,
      merchantId: merchant,
      merchantName: name is String && name.isNotEmpty
          ? name
          : (merchant.isEmpty ? 'その他' : merchant),
      instrumentId: instrumentId is String && instrumentId.isNotEmpty
          ? instrumentId
          : fallbackInstrumentId,
      amountYen: amount,
    );
  }
}

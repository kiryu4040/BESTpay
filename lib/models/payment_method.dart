class PaymentMethod {
  final int? id;
  final String name;
  final String type; // credit/debit/qr/emoney/point
  final String issuer;
  final double baseRate; // %
  final int annualFee;
  bool enabled;
  final String color; // hex
  final String note;

  PaymentMethod({
    this.id,
    required this.name,
    required this.type,
    required this.issuer,
    required this.baseRate,
    required this.annualFee,
    this.enabled = true,
    required this.color,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'issuer': issuer,
        'base_rate': baseRate,
        'annual_fee': annualFee,
        'enabled': enabled ? 1 : 0,
        'color': color,
        'note': note,
      };

  factory PaymentMethod.fromMap(Map<String, dynamic> m) => PaymentMethod(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: m['type'] as String? ?? 'credit',
        issuer: m['issuer'] as String? ?? '',
        baseRate: (m['base_rate'] as num?)?.toDouble() ?? 0.0,
        annualFee: (m['annual_fee'] as int?) ?? 0,
        enabled: (m['enabled'] as int?) == 1,
        color: m['color'] as String? ?? '#1976D2',
        note: m['note'] as String? ?? '',
      );

  String get typeLabel {
    switch (type) {
      case 'credit':
        return 'クレジット';
      case 'debit':
        return 'デビット';
      case 'qr':
        return 'QR決済';
      case 'emoney':
        return '電子マネー';
      case 'point':
        return 'ポイント';
      default:
        return type;
    }
  }
}

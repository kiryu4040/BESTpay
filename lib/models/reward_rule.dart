class RewardRule {
  final int? id;
  final int storeId;
  final int paymentId;
  final double baseBonus;
  final double maxBonus;
  final String conditionKey;
  final String note;

  RewardRule({
    this.id,
    required this.storeId,
    required this.paymentId,
    required this.baseBonus,
    required this.maxBonus,
    this.conditionKey = '',
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'store_id': storeId,
        'payment_id': paymentId,
        'base_bonus': baseBonus,
        'max_bonus': maxBonus,
        'condition_key': conditionKey,
        'note': note,
      };

  factory RewardRule.fromMap(Map<String, dynamic> m) => RewardRule(
        id: m['id'] as int?,
        storeId: m['store_id'] as int,
        paymentId: m['payment_id'] as int,
        baseBonus: (m['base_bonus'] as num?)?.toDouble() ?? 0.0,
        maxBonus: (m['max_bonus'] as num?)?.toDouble() ?? 0.0,
        conditionKey: m['condition_key'] as String? ?? '',
        note: m['note'] as String? ?? '',
      );
}

class CustomRule {
  final int? id;
  final int storeId;
  final int paymentId;
  final double customRate;
  final String memo;
  final String createdAt;

  CustomRule({
    this.id,
    required this.storeId,
    required this.paymentId,
    required this.customRate,
    this.memo = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'store_id': storeId,
        'payment_id': paymentId,
        'custom_rate': customRate,
        'memo': memo,
        'created_at': createdAt,
      };

  factory CustomRule.fromMap(Map<String, dynamic> m) => CustomRule(
        id: m['id'] as int?,
        storeId: m['store_id'] as int,
        paymentId: m['payment_id'] as int,
        customRate: (m['custom_rate'] as num?)?.toDouble() ?? 0.0,
        memo: m['memo'] as String? ?? '',
        createdAt: m['created_at'] as String? ?? '',
      );
}

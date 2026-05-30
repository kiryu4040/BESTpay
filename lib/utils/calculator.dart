import '../models/payment_method.dart';
import '../models/reward_rule.dart';
import '../models/user_condition.dart';

class RankItem {
  final PaymentMethod payment;
  final double rate;
  final double rewardYen;
  final String note;
  final bool conditionApplied;
  final double baseRate;
  final double bonusRate;
  final double conditionRate;

  RankItem({
    required this.payment,
    required this.rate,
    required this.rewardYen,
    required this.note,
    required this.conditionApplied,
    required this.baseRate,
    required this.bonusRate,
    required this.conditionRate,
  });
}

class Calculator {
  static List<RankItem> rank({
    required int storeId,
    required int amount,
    required List<PaymentMethod> payments,
    required List<RewardRule> storeRules,
    required Map<String, String> conditions,
    Map<int, double>? customRates,
  }) {
    final ruleMap = <int, RewardRule>{};
    for (final r in storeRules) {
      ruleMap[r.paymentId] = r;
    }

    final items = <RankItem>[];

    for (final p in payments) {
      if (!p.enabled) continue;

      if (customRates != null && customRates.containsKey(p.id)) {
        final rate = customRates[p.id]!;
        items.add(RankItem(
          payment: p,
          rate: rate,
          rewardYen: amount * rate / 100.0,
          note: 'カスタムルール適用',
          conditionApplied: false,
          baseRate: p.baseRate,
          bonusRate: rate - p.baseRate,
          conditionRate: 0,
        ));
        continue;
      }

      final rule = ruleMap[p.id];
      final base = p.baseRate;
      final storeBonus = rule?.baseBonus ?? 0.0;
      final maxBonus = rule?.maxBonus ?? 0.0;
      final conditionKey = rule?.conditionKey ?? '';

      double conditionRate = 0.0;
      bool conditionApplied = false;

      if (conditionKey.isNotEmpty && maxBonus > 0) {
        conditionRate =
            _computeConditionBonus(conditionKey, conditions, maxBonus);
        conditionApplied = conditionRate > 0;
      }

      final totalRate = base + storeBonus + conditionRate;
      final reward = amount * totalRate / 100.0;

      items.add(RankItem(
        payment: p,
        rate: totalRate,
        rewardYen: reward,
        note: rule?.note ?? '',
        conditionApplied: conditionApplied,
        baseRate: base,
        bonusRate: storeBonus,
        conditionRate: conditionRate,
      ));
    }

    items.sort((a, b) => b.rate.compareTo(a.rate));
    return items;
  }

  static double _computeConditionBonus(
      String key, Map<String, String> c, double maxBonus) {
    bool b(String k) => c[k] == '1';
    int i(String k) => int.tryParse(c[k] ?? '0') ?? 0;

    double bonus = 0.0;

    switch (key) {
      case 'smbc_vpoint':
        final olive = c[UserConditionKeys.oliveAccount] ?? 'none';
        if (olive == 'gold') {
          bonus += 2.0;
        } else if (olive == 'standard') {
          bonus += 1.0;
        }
        if (b(UserConditionKeys.sbiSecurities)) bonus += 2.0;
        final fam = i(UserConditionKeys.familyPoints);
        bonus += (fam > 5 ? 5 : fam).toDouble();
        if (b(UserConditionKeys.selectableBenefit)) bonus += 1.0;
        if (b(UserConditionKeys.smbcAppLogin)) bonus += 1.0;
        if (b(UserConditionKeys.vpointAppLogin)) bonus += 1.0;
        if (b(UserConditionKeys.housingLoan)) bonus += 1.0;
        break;

      case 'mufg_program':
        if (b(UserConditionKeys.mufgAppLogin)) bonus += 0.5;
        final lvl = i(UserConditionKeys.mufgMonthlyUse);
        const ladder = [0.0, 2.0, 5.0, 12.0];
        if (lvl >= 0 && lvl < ladder.length) bonus += ladder[lvl];
        break;

      case 'paypay_step':
        if (b(UserConditionKeys.paypay30Times) &&
            b(UserConditionKeys.paypay100KYen)) {
          bonus += 0.5;
        }
        if (b(UserConditionKeys.paypayGold)) bonus += 0.5;
        break;

      case 'lyp_premium':
        if (b(UserConditionKeys.lypPremium)) bonus += 2.0;
        if (b(UserConditionKeys.sundayBonus)) bonus += 3.0;
        break;

      case 'rakuten_spu':
        if (b(UserConditionKeys.rakutenMobile)) bonus += 4.0;
        if (b(UserConditionKeys.rakutenBank)) bonus += 1.0;
        if (b(UserConditionKeys.rakutenSecurities)) bonus += 0.5;
        if (b(UserConditionKeys.rakutenHikari)) bonus += 2.0;
        if (b(UserConditionKeys.rakutenTravel)) bonus += 1.0;
        if (b(UserConditionKeys.fiveZeroDay)) bonus += 2.0;
        break;
    }

    return bonus.clamp(0.0, maxBonus);
  }

  static double monthlyEstimate({
    required double rate,
    required int monthlyAmount,
  }) =>
      monthlyAmount * rate / 100.0;

  static double yearlyEstimate({
    required double rate,
    required int monthlyAmount,
  }) =>
      monthlyEstimate(rate: rate, monthlyAmount: monthlyAmount) * 12;
}

import 'package:bestpay/models/payment_method.dart';
import 'package:bestpay/models/reward_rule.dart';
import 'package:bestpay/models/user_condition.dart';
import 'package:bestpay/utils/calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PaymentMethod payment({
    required int id,
    double baseRate = 0.5,
    String? name,
  }) {
    return PaymentMethod(
      id: id,
      name: name ?? 'Payment $id',
      type: 'credit',
      issuer: 'Test issuer',
      baseRate: baseRate,
      annualFee: 0,
      color: '#000000',
    );
  }

  RewardRule conditionalRule({
    required int paymentId,
    required String conditionKey,
    required double maxBonus,
  }) {
    return RewardRule(
      storeId: 1,
      paymentId: paymentId,
      baseBonus: 0,
      maxBonus: maxBonus,
      conditionKey: conditionKey,
    );
  }

  RankItem calculateCondition({
    required String conditionKey,
    required double maxBonus,
    required Map<String, String> conditions,
    double baseRate = 0.5,
  }) {
    return Calculator.rank(
      storeId: 1,
      amount: 1000,
      payments: [payment(id: 1, baseRate: baseRate)],
      storeRules: [
        conditionalRule(
          paymentId: 1,
          conditionKey: conditionKey,
          maxBonus: maxBonus,
        ),
      ],
      conditions: conditions,
    ).single;
  }

  group('Additional condition characterization', () {
    test('MUFG applies app login and monthly level three', () {
      final result = calculateCondition(
        conditionKey: 'mufg_program',
        maxBonus: 20,
        conditions: const {
          UserConditionKeys.mufgAppLogin: '1',
          UserConditionKeys.mufgMonthlyUse: '3',
        },
      );

      expect(result.conditionRate, 12.5);
      expect(result.rate, 13.0);
      expect(result.conditionApplied, isTrue);
    });

    test('MUFG ignores an out-of-range monthly level', () {
      final result = calculateCondition(
        conditionKey: 'mufg_program',
        maxBonus: 20,
        conditions: const {
          UserConditionKeys.mufgAppLogin: '1',
          UserConditionKeys.mufgMonthlyUse: '99',
        },
      );

      expect(result.conditionRate, 0.5);
      expect(result.rate, 1.0);
    });

    test('LYP premium adds premium and Sunday bonuses', () {
      final result = calculateCondition(
        conditionKey: 'lyp_premium',
        maxBonus: 10,
        conditions: const {
          UserConditionKeys.lypPremium: '1',
          UserConditionKeys.sundayBonus: '1',
        },
      );

      expect(result.conditionRate, 5.0);
      expect(result.rate, 5.5);
      expect(result.conditionApplied, isTrue);
    });

    test('Rakuten SPU adds every currently supported condition', () {
      final result = calculateCondition(
        conditionKey: 'rakuten_spu',
        maxBonus: 20,
        conditions: const {
          UserConditionKeys.rakutenMobile: '1',
          UserConditionKeys.rakutenBank: '1',
          UserConditionKeys.rakutenSecurities: '1',
          UserConditionKeys.rakutenHikari: '1',
          UserConditionKeys.rakutenTravel: '1',
          UserConditionKeys.fiveZeroDay: '1',
        },
        baseRate: 1.0,
      );

      expect(result.conditionRate, 10.5);
      expect(result.rate, 11.5);
      expect(result.conditionApplied, isTrue);
    });

    test('SMBC family points are capped at five', () {
      final result = calculateCondition(
        conditionKey: 'smbc_vpoint',
        maxBonus: 20,
        conditions: const {
          UserConditionKeys.familyPoints: '99',
        },
      );

      expect(result.conditionRate, 5.0);
      expect(result.rate, 5.5);
    });

    test('malformed numeric condition currently becomes zero', () {
      final result = calculateCondition(
        conditionKey: 'mufg_program',
        maxBonus: 20,
        conditions: const {
          UserConditionKeys.mufgMonthlyUse: 'not-a-number',
        },
      );

      expect(result.conditionRate, 0.0);
      expect(result.conditionApplied, isFalse);
    });

    test('maxBonus zero prevents condition evaluation', () {
      final result = calculateCondition(
        conditionKey: 'lyp_premium',
        maxBonus: 0,
        conditions: const {
          UserConditionKeys.lypPremium: '1',
          UserConditionKeys.sundayBonus: '1',
        },
      );

      expect(result.conditionRate, 0.0);
      expect(result.conditionApplied, isFalse);
    });
  });

  group('Additional ranking characterization', () {
    test('equal rates currently keep the supplied payment order', () {
      final result = Calculator.rank(
        storeId: 1,
        amount: 1000,
        payments: [
          payment(id: 3, baseRate: 1.0),
          payment(id: 1, baseRate: 1.0),
          payment(id: 2, baseRate: 1.0),
        ],
        storeRules: const [],
        conditions: const {},
      );

      expect(
        result.map((item) => item.payment.id).toList(),
        [3, 1, 2],
      );
    });

    test('zero amount produces zero reward without removing rankings', () {
      final result = Calculator.rank(
        storeId: 1,
        amount: 0,
        payments: [
          payment(id: 1, baseRate: 1.0),
          payment(id: 2, baseRate: 2.0),
        ],
        storeRules: const [],
        conditions: const {},
      );

      expect(result, hasLength(2));
      expect(result.every((item) => item.rewardYen == 0), isTrue);
      expect(result.map((item) => item.payment.id).toList(), [2, 1]);
    });
  });
}

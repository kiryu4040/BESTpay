import 'package:bestpay/models/payment_method.dart';
import 'package:bestpay/models/reward_rule.dart';
import 'package:bestpay/models/user_condition.dart';
import 'package:bestpay/utils/calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PaymentMethod payment({
    required int id,
    required double baseRate,
    bool enabled = true,
    String name = 'Test payment',
  }) {
    return PaymentMethod(
      id: id,
      name: name,
      type: 'credit',
      issuer: 'Test issuer',
      baseRate: baseRate,
      annualFee: 0,
      enabled: enabled,
      color: '#000000',
    );
  }

  RewardRule rule({
    required int paymentId,
    double baseBonus = 0,
    double maxBonus = 0,
    String conditionKey = '',
    String note = '',
  }) {
    return RewardRule(
      id: paymentId,
      storeId: 1,
      paymentId: paymentId,
      baseBonus: baseBonus,
      maxBonus: maxBonus,
      conditionKey: conditionKey,
      note: note,
    );
  }

  group('Calculator.rank legacy characterization', () {
    test('uses the payment base rate when no store rule exists', () {
      final result = Calculator.rank(
        storeId: 1,
        amount: 1000,
        payments: [payment(id: 1, baseRate: 1.5)],
        storeRules: const [],
        conditions: const {},
      );

      expect(result, hasLength(1));
      expect(result.single.rate, 1.5);
      expect(result.single.rewardYen, 15.0);
      expect(result.single.baseRate, 1.5);
      expect(result.single.bonusRate, 0.0);
      expect(result.single.conditionRate, 0.0);
      expect(result.single.conditionApplied, isFalse);
      expect(result.single.note, isEmpty);
    });

    test('excludes disabled payment methods', () {
      final result = Calculator.rank(
        storeId: 1,
        amount: 1000,
        payments: [
          payment(id: 1, baseRate: 1.0, enabled: true),
          payment(id: 2, baseRate: 10.0, enabled: false),
        ],
        storeRules: const [],
        conditions: const {},
      );

      expect(result, hasLength(1));
      expect(result.single.payment.id, 1);
    });

    test('adds a store base bonus to the payment base rate', () {
      final result = Calculator.rank(
        storeId: 1,
        amount: 2000,
        payments: [payment(id: 1, baseRate: 0.5)],
        storeRules: [
          rule(
            paymentId: 1,
            baseBonus: 4.5,
            note: '店舗特典',
          ),
        ],
        conditions: const {},
      );

      expect(result.single.rate, 5.0);
      expect(result.single.rewardYen, 100.0);
      expect(result.single.baseRate, 0.5);
      expect(result.single.bonusRate, 4.5);
      expect(result.single.conditionRate, 0.0);
      expect(result.single.note, '店舗特典');
    });

    test('sorts enabled payment methods by descending rate', () {
      final result = Calculator.rank(
        storeId: 1,
        amount: 1000,
        payments: [
          payment(id: 1, baseRate: 0.5, name: 'Low'),
          payment(id: 2, baseRate: 2.0, name: 'High'),
          payment(id: 3, baseRate: 1.0, name: 'Middle'),
        ],
        storeRules: const [],
        conditions: const {},
      );

      expect(
        result.map((item) => item.payment.id).toList(),
        [2, 3, 1],
      );
    });

    test('uses the last rule when duplicate payment rules are supplied', () {
      final result = Calculator.rank(
        storeId: 1,
        amount: 1000,
        payments: [payment(id: 1, baseRate: 1.0)],
        storeRules: [
          rule(paymentId: 1, baseBonus: 1.0, note: 'first'),
          rule(paymentId: 1, baseBonus: 3.0, note: 'last'),
        ],
        conditions: const {},
      );

      expect(result.single.rate, 4.0);
      expect(result.single.bonusRate, 3.0);
      expect(result.single.note, 'last');
    });

    test('custom rate replaces the normal calculated rate', () {
      final result = Calculator.rank(
        storeId: 1,
        amount: 2000,
        payments: [payment(id: 1, baseRate: 1.0)],
        storeRules: [
          rule(
            paymentId: 1,
            baseBonus: 4.0,
            maxBonus: 10.0,
            conditionKey: 'smbc_vpoint',
          ),
        ],
        conditions: const {
          UserConditionKeys.oliveAccount: 'gold',
          UserConditionKeys.sbiSecurities: '1',
        },
        customRates: const {1: 3.25},
      );

      expect(result.single.rate, 3.25);
      expect(result.single.rewardYen, 65.0);
      expect(result.single.baseRate, 1.0);
      expect(result.single.bonusRate, 2.25);
      expect(result.single.conditionRate, 0.0);
      expect(result.single.conditionApplied, isFalse);
      expect(result.single.note, 'カスタムルール適用');
    });

    test('SMBC condition bonus is capped by maxBonus', () {
      final result = Calculator.rank(
        storeId: 1,
        amount: 1000,
        payments: [payment(id: 1, baseRate: 0.5)],
        storeRules: [
          rule(
            paymentId: 1,
            baseBonus: 5.0,
            maxBonus: 3.0,
            conditionKey: 'smbc_vpoint',
          ),
        ],
        conditions: const {
          UserConditionKeys.oliveAccount: 'gold',
          UserConditionKeys.sbiSecurities: '1',
          UserConditionKeys.familyPoints: '5',
          UserConditionKeys.selectableBenefit: '1',
          UserConditionKeys.smbcAppLogin: '1',
          UserConditionKeys.vpointAppLogin: '1',
          UserConditionKeys.housingLoan: '1',
        },
      );

      expect(result.single.conditionRate, 3.0);
      expect(result.single.rate, 8.5);
      expect(result.single.conditionApplied, isTrue);
    });

    test('PayPay step requires both usage conditions', () {
      final incomplete = Calculator.rank(
        storeId: 1,
        amount: 1000,
        payments: [payment(id: 1, baseRate: 1.0)],
        storeRules: [
          rule(
            paymentId: 1,
            maxBonus: 1.0,
            conditionKey: 'paypay_step',
          ),
        ],
        conditions: const {
          UserConditionKeys.paypay30Times: '1',
          UserConditionKeys.paypay100KYen: '0',
        },
      );

      final complete = Calculator.rank(
        storeId: 1,
        amount: 1000,
        payments: [payment(id: 1, baseRate: 1.0)],
        storeRules: [
          rule(
            paymentId: 1,
            maxBonus: 1.0,
            conditionKey: 'paypay_step',
          ),
        ],
        conditions: const {
          UserConditionKeys.paypay30Times: '1',
          UserConditionKeys.paypay100KYen: '1',
          UserConditionKeys.paypayGold: '1',
        },
      );

      expect(incomplete.single.conditionRate, 0.0);
      expect(incomplete.single.conditionApplied, isFalse);
      expect(complete.single.conditionRate, 1.0);
      expect(complete.single.conditionApplied, isTrue);
    });

    test('unknown condition key contributes no condition bonus', () {
      final result = Calculator.rank(
        storeId: 1,
        amount: 1000,
        payments: [payment(id: 1, baseRate: 1.0)],
        storeRules: [
          rule(
            paymentId: 1,
            baseBonus: 2.0,
            maxBonus: 10.0,
            conditionKey: 'unknown_condition',
          ),
        ],
        conditions: const {'unknown_condition': '1'},
      );

      expect(result.single.rate, 3.0);
      expect(result.single.conditionRate, 0.0);
      expect(result.single.conditionApplied, isFalse);
    });

    test('currently permits a negative amount and returns a negative reward',
        () {
      final result = Calculator.rank(
        storeId: 1,
        amount: -1000,
        payments: [payment(id: 1, baseRate: 1.0)],
        storeRules: const [],
        conditions: const {},
      );

      expect(result.single.rewardYen, -10.0);
    });
  });

  group('Calculator estimate legacy characterization', () {
    test('calculates the monthly estimate', () {
      expect(
        Calculator.monthlyEstimate(
          rate: 1.5,
          monthlyAmount: 10000,
        ),
        150.0,
      );
    });

    test('calculates the yearly estimate as twelve monthly estimates', () {
      expect(
        Calculator.yearlyEstimate(
          rate: 1.5,
          monthlyAmount: 10000,
        ),
        1800.0,
      );
    });

    test('currently permits a negative monthly amount', () {
      expect(
        Calculator.monthlyEstimate(
          rate: 1.0,
          monthlyAmount: -1000,
        ),
        -10.0,
      );
    });
  });
}

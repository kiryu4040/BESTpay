import 'package:bestpay/models/payment_method.dart';
import 'package:bestpay/models/reward_rule.dart';
import 'package:bestpay/models/store.dart';
import 'package:bestpay/models/user_condition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentMethod legacy characterization', () {
    test('round-trips all stored fields through a map', () {
      final original = PaymentMethod(
        id: 7,
        name: 'Test Card',
        type: 'credit',
        issuer: 'Test Issuer',
        baseRate: 1.5,
        annualFee: 1100,
        enabled: true,
        color: '#123456',
        note: 'test note',
      );

      final restored = PaymentMethod.fromMap(original.toMap());

      expect(restored.toMap(), original.toMap());
    });

    test('uses current fallback values when nullable columns are missing', () {
      final result = PaymentMethod.fromMap(
        <String, dynamic>{
          'id': 1,
          'name': 'Minimal Card',
        },
      );

      expect(result.id, 1);
      expect(result.name, 'Minimal Card');
      expect(result.type, 'credit');
      expect(result.issuer, '');
      expect(result.baseRate, 0.0);
      expect(result.annualFee, 0);
      expect(result.enabled, isFalse);
      expect(result.color, '#1976D2');
      expect(result.note, '');
    });

    test('returns current Japanese labels for known payment types', () {
      final expected = <String, String>{
        'credit': 'クレジット',
        'debit': 'デビット',
        'qr': 'QR決済',
        'emoney': '電子マネー',
        'point': 'ポイント',
      };

      for (final entry in expected.entries) {
        final method = PaymentMethod(
          id: 1,
          name: 'Test',
          type: entry.key,
          issuer: '',
          baseRate: 0,
          annualFee: 0,
          color: '#000000',
        );

        expect(method.typeLabel, entry.value);
      }
    });

    test('returns the raw type when the payment type is unknown', () {
      final method = PaymentMethod(
        id: 1,
        name: 'Test',
        type: 'future_type',
        issuer: '',
        baseRate: 0,
        annualFee: 0,
        color: '#000000',
      );

      expect(method.typeLabel, 'future_type');
    });
  });

  group('RewardRule legacy characterization', () {
    test('round-trips all stored fields through a map', () {
      final original = RewardRule(
        id: 10,
        storeId: 20,
        paymentId: 30,
        baseBonus: 2.5,
        maxBonus: 7.0,
        conditionKey: 'smbc_vpoint',
        note: 'test rule',
      );

      final restored = RewardRule.fromMap(original.toMap());

      expect(restored.toMap(), original.toMap());
    });

    test('uses current fallback values for nullable rule columns', () {
      final result = RewardRule.fromMap(
        <String, dynamic>{
          'id': 10,
          'store_id': 20,
          'payment_id': 30,
        },
      );

      expect(result.baseBonus, 0.0);
      expect(result.maxBonus, 0.0);
      expect(result.conditionKey, '');
      expect(result.note, '');
    });
  });

  group('CustomRule legacy characterization', () {
    test('round-trips all stored fields through a map', () {
      final original = CustomRule(
        id: 4,
        storeId: 5,
        paymentId: 6,
        customRate: 3.25,
        memo: 'custom memo',
        createdAt: '2026-09-14T00:00:00Z',
      );

      final restored = CustomRule.fromMap(original.toMap());

      expect(restored.toMap(), original.toMap());
    });

    test('uses empty strings for missing memo and creation time', () {
      final result = CustomRule.fromMap(
        <String, dynamic>{
          'id': 4,
          'store_id': 5,
          'payment_id': 6,
          'custom_rate': 3.25,
        },
      );

      expect(result.memo, '');
      expect(result.createdAt, '');
    });
  });

  group('Store legacy characterization', () {
    test('round-trips all stored fields through a map', () {
      final original = Store(
        id: 8,
        name: 'Test Store',
        category: 'convenience',
        aliases: 'test,store',
        icon: '🏪',
        isFavorite: true,
      );

      final restored = Store.fromMap(original.toMap());

      expect(restored.toMap(), original.toMap());
    });

    test('uses current fallback values for nullable store columns', () {
      final result = Store.fromMap(
        <String, dynamic>{
          'id': 8,
          'name': 'Minimal Store',
        },
      );

      expect(result.category, 'other');
      expect(result.aliases, '');
      expect(result.icon, '🏪');
      expect(result.isFavorite, isFalse);
    });

    test('returns current category labels and fallback behavior', () {
      expect(Store.categoryLabel('convenience'), 'コンビニ');
      expect(Store.categoryLabel('restaurant'), 'ファミレス／飲食');
      expect(Store.categoryLabel('ec'), 'EC／ネット');
      expect(Store.categoryLabel('other'), 'その他');
      expect(Store.categoryLabel('future_category'), 'future_category');
    });

    test('returns current category icons and fallback icon', () {
      expect(Store.categoryIcon('convenience'), '🏪');
      expect(Store.categoryIcon('restaurant'), '🍝');
      expect(Store.categoryIcon('cafe'), '☕');
      expect(Store.categoryIcon('future_category'), '🏷️');
    });
  });

  group('UserConditionKeys legacy characterization', () {
    test('returns the current complete default condition map', () {
      final defaults = UserConditionKeys.defaults();

      expect(defaults, hasLength(22));
      expect(defaults[UserConditionKeys.oliveAccount], 'none');

      final zeroKeys = <String>[
        UserConditionKeys.sbiSecurities,
        UserConditionKeys.familyPoints,
        UserConditionKeys.selectableBenefit,
        UserConditionKeys.annualUse100Man,
        UserConditionKeys.smbcAppLogin,
        UserConditionKeys.vpointAppLogin,
        UserConditionKeys.housingLoan,
        UserConditionKeys.paypay30Times,
        UserConditionKeys.paypay100KYen,
        UserConditionKeys.paypayGold,
        UserConditionKeys.rakutenMobile,
        UserConditionKeys.rakutenBank,
        UserConditionKeys.rakutenSecurities,
        UserConditionKeys.rakutenHikari,
        UserConditionKeys.rakutenTravel,
        UserConditionKeys.fiveZeroDay,
        UserConditionKeys.lypPremium,
        UserConditionKeys.sundayBonus,
        UserConditionKeys.mufgAppLogin,
        UserConditionKeys.mufgMonthlyUse,
        UserConditionKeys.welKatsu,
      ];

      for (final key in zeroKeys) {
        expect(defaults[key], '0', reason: 'Unexpected default for $key');
      }
    });

    test('returns a new mutable map for every defaults call', () {
      final first = UserConditionKeys.defaults();
      final second = UserConditionKeys.defaults();

      first[UserConditionKeys.sbiSecurities] = '1';

      expect(second[UserConditionKeys.sbiSecurities], '0');
    });
  });
}

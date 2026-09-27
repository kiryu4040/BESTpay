import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StableId', () {
    test('accepts identifiers at the minimum and maximum lengths', () {
      final minimum = _success(StableId.create('abc'));
      final maximumValue = 'a${List<String>.filled(79, '1').join()}';
      final maximum = _success(StableId.create(maximumValue));

      expect(minimum.value, 'abc');
      expect(maximum.value, maximumValue);
      expect(maximum.value.length, StableId.maximumLength);
    });

    test('accepts lowercase identifiers with digits and underscores', () {
      final paymentId = _success(StableId.create('mizuho_rakuten_card_2026'));

      expect(paymentId.value, 'mizuho_rakuten_card_2026');
    });

    test('rejects values shorter than the minimum length', () {
      for (final value in <String>['', 'a', 'ab']) {
        final error = _failure(StableId.create(value));

        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'stableId.create');
        expect(error.retryable, isFalse);
      }
    });

    test('rejects values longer than the maximum length', () {
      final value = 'a${List<String>.filled(80, '1').join()}';

      expect(value.length, StableId.maximumLength + 1);

      final error = _failure(StableId.create(value));

      expect(error.code, AppErrorCode.invalidArgument);
      expect(error.operation, 'stableId.create');
      expect(error.retryable, isFalse);
    });

    test('rejects invalid starting characters and uppercase letters', () {
      final invalidValues = <String>['1card', '_card', 'Card', 'cardName'];

      for (final value in invalidValues) {
        final error = _failure(StableId.create(value));

        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'stableId.create');
      }
    });

    test('rejects spaces, hyphens, periods, and non-ASCII characters', () {
      final invalidValues = <String>[
        'card name',
        'card-name',
        'card.name',
        'card\n',
        'カード',
      ];

      for (final value in invalidValues) {
        final error = _failure(StableId.create(value));

        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'stableId.create');
      }
    });

    test('does not trim or normalize input automatically', () {
      expect(StableId.create(' card'), isA<AppFailure<StableId>>());
      expect(StableId.create('card '), isA<AppFailure<StableId>>());
      expect(StableId.create('CARD'), isA<AppFailure<StableId>>());
    });

    test('uses the validated string for equality and hashCode', () {
      final first = _success(StableId.create('payment_card'));
      final second = _success(StableId.create('payment_card'));
      final different = _success(StableId.create('payment_card_2'));

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('provides a debug representation without changing the value', () {
      final id = _success(StableId.create('payment_card'));

      expect(id.toString(), 'StableId(payment_card)');
      expect(id.value, 'payment_card');
    });
  });
}

StableId _success(AppResult<StableId> result) {
  expect(result, isA<AppSuccess<StableId>>());
  return (result as AppSuccess<StableId>).value;
}

AppError _failure(AppResult<StableId> result) {
  expect(result, isA<AppFailure<StableId>>());
  return (result as AppFailure<StableId>).error;
}

import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StableId', () {
    test('accepts lowercase identifiers with digits and underscores', () {
      final shortest = _success(StableId.create('a'));
      final paymentId = _success(
        StableId.create('mizuho_rakuten_card_2026'),
      );

      expect(shortest.value, 'a');
      expect(paymentId.value, 'mizuho_rakuten_card_2026');
    });

    test('rejects empty and whitespace-only values', () {
      for (final value in <String>['', ' ', '   ']) {
        final error = _failure(StableId.create(value));

        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'stableId.create');
        expect(error.retryable, isFalse);
      }
    });

    test('rejects invalid starting characters and uppercase letters', () {
      final invalidValues = <String>[
        '1card',
        '_card',
        'Card',
        'cardName',
      ];

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
        'カード',
      ];

      for (final value in invalidValues) {
        final error = _failure(StableId.create(value));

        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'stableId.create');
      }
    });

    test('does not trim or normalize input automatically', () {
      expect(
        StableId.create(' card'),
        isA<AppFailure<StableId>>(),
      );
      expect(
        StableId.create('card '),
        isA<AppFailure<StableId>>(),
      );
      expect(
        StableId.create('CARD'),
        isA<AppFailure<StableId>>(),
      );
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

import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/catalog_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogVersion', () {
    test('accepts supported opaque version formats', () {
      final validValues = <String>[
        '1',
        'v2',
        '2026.09.14',
        'catalog-v2_1',
        'V2-beta.1',
      ];

      for (final value in validValues) {
        final version = _success(CatalogVersion.create(value));
        expect(version.value, value);
      }
    });

    test('rejects empty and whitespace-only values', () {
      for (final value in <String>['', ' ', '   ']) {
        final error = _failure(CatalogVersion.create(value));

        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'catalogVersion.create');
        expect(error.retryable, isFalse);
      }
    });

    test('rejects punctuation as the first character', () {
      for (final value in <String>['.v2', '-v2', '_v2']) {
        final error = _failure(CatalogVersion.create(value));

        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'catalogVersion.create');
      }
    });

    test('rejects unsupported characters', () {
      final invalidValues = <String>[
        'version 2',
        'version/2',
        'version+2',
        'v2\n',
        'バージョン2',
      ];

      for (final value in invalidValues) {
        final error = _failure(CatalogVersion.create(value));

        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'catalogVersion.create');
      }
    });

    test('does not trim or normalize input automatically', () {
      expect(
        CatalogVersion.create(' v2'),
        isA<AppFailure<CatalogVersion>>(),
      );
      expect(
        CatalogVersion.create('v2 '),
        isA<AppFailure<CatalogVersion>>(),
      );

      final uppercase = _success(CatalogVersion.create('V2'));
      expect(uppercase.value, 'V2');
    });

    test('uses exact case-sensitive equality', () {
      final first = _success(CatalogVersion.create('v2'));
      final second = _success(CatalogVersion.create('v2'));
      final uppercase = _success(CatalogVersion.create('V2'));

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(uppercase));
    });

    test('provides a debug representation without changing the value', () {
      final version = _success(
        CatalogVersion.create('2026.09.14'),
      );

      expect(
        version.toString(),
        'CatalogVersion(2026.09.14)',
      );
      expect(version.value, '2026.09.14');
    });
  });
}

CatalogVersion _success(AppResult<CatalogVersion> result) {
  expect(result, isA<AppSuccess<CatalogVersion>>());
  return (result as AppSuccess<CatalogVersion>).value;
}

AppError _failure(AppResult<CatalogVersion> result) {
  expect(result, isA<AppFailure<CatalogVersion>>());
  return (result as AppFailure<CatalogVersion>).error;
}

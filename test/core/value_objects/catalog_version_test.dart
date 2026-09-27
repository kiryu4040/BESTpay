import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/catalog_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogVersion', () {
    test('accepts the YYYY.MM.DD.REVISION format', () {
      final first = _success(CatalogVersion.create('2026.09.17.1'));
      final second = _success(CatalogVersion.create('2026.12.31.9'));
      final leapDay = _success(CatalogVersion.create('2028.02.29.12'));

      expect(first.value, '2026.09.17.1');
      expect(first.year, 2026);
      expect(first.month, 9);
      expect(first.day, 17);
      expect(first.revision, 1);

      expect(second.value, '2026.12.31.9');
      expect(second.revision, 9);

      expect(leapDay.value, '2028.02.29.12');
      expect(leapDay.year, 2028);
      expect(leapDay.month, 2);
      expect(leapDay.day, 29);
      expect(leapDay.revision, 12);
    });

    test('rejects old opaque version formats', () {
      final invalidValues = <String>[
        '1',
        'v2',
        '2026.09.17',
        'catalog-v2_1',
        'V2-beta.1',
      ];

      for (final value in invalidValues) {
        final error = _failure(CatalogVersion.create(value));

        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'catalogVersion.create');
        expect(error.retryable, isFalse);
      }
    });

    test('rejects incorrectly padded date components', () {
      final invalidValues = <String>[
        '2026.9.17.1',
        '2026.09.7.1',
        '026.09.17.1',
        '02026.09.17.1',
      ];

      for (final value in invalidValues) {
        expect(CatalogVersion.create(value), isA<AppFailure<CatalogVersion>>());
      }
    });

    test('rejects invalid calendar dates', () {
      final invalidValues = <String>[
        '0000.01.01.1',
        '2026.00.01.1',
        '2026.13.01.1',
        '2026.01.00.1',
        '2026.01.32.1',
        '2026.02.29.1',
        '2026.02.30.1',
        '2026.04.31.1',
        '2100.02.29.1',
      ];

      for (final value in invalidValues) {
        final error = _failure(CatalogVersion.create(value));

        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'catalogVersion.create');
      }
    });

    test('accepts Gregorian leap years', () {
      final validValues = <String>[
        '2000.02.29.1',
        '2024.02.29.1',
        '2028.02.29.1',
      ];

      for (final value in validValues) {
        expect(CatalogVersion.create(value), isA<AppSuccess<CatalogVersion>>());
      }
    });

    test('rejects zero or zero-padded revisions', () {
      final invalidValues = <String>[
        '2026.09.17.0',
        '2026.09.17.00',
        '2026.09.17.01',
      ];

      for (final value in invalidValues) {
        expect(CatalogVersion.create(value), isA<AppFailure<CatalogVersion>>());
      }
    });

    test('rejects unsupported characters and extra whitespace', () {
      final invalidValues = <String>[
        '2026-09-17-1',
        '2026/09/17/1',
        '2026.09.17.a',
        ' 2026.09.17.1',
        '2026.09.17.1 ',
        '2026.09.17.1\n',
        '２０２６.０９.１７.１',
      ];

      for (final value in invalidValues) {
        final error = _failure(CatalogVersion.create(value));

        expect(error.code, AppErrorCode.invalidArgument);
        expect(error.operation, 'catalogVersion.create');
      }
    });

    test('rejects a revision that cannot be represented as an int', () {
      final hugeRevision = List<String>.filled(1000, '9').join();
      final value = '2026.09.17.$hugeRevision';

      expect(CatalogVersion.create(value), isA<AppFailure<CatalogVersion>>());
    });

    test('uses exact string equality', () {
      final first = _success(CatalogVersion.create('2026.09.17.1'));
      final second = _success(CatalogVersion.create('2026.09.17.1'));
      final differentRevision = _success(CatalogVersion.create('2026.09.17.2'));

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(differentRevision));
    });

    test('provides a debug representation without changing the value', () {
      final version = _success(CatalogVersion.create('2026.09.17.1'));

      expect(version.toString(), 'CatalogVersion(2026.09.17.1)');
      expect(version.value, '2026.09.17.1');
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

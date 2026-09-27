import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppResult', () {
    test('AppSuccess holds a value and reports its state', () {
      const AppResult<int> result = AppSuccess<int>(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect((result as AppSuccess<int>).value, 42);
    });

    test('AppFailure holds an error and reports its state', () {
      final error = AppError(
        code: AppErrorCode.databaseReadFailed,
        operation: 'database.read',
      );
      final AppResult<int> result = AppFailure<int>(error);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect((result as AppFailure<int>).error, same(error));
    });

    test('map transforms a successful value', () {
      const AppResult<int> result = AppSuccess<int>(21);

      final mapped = result.map((value) => value * 2);

      expect(mapped, isA<AppSuccess<int>>());
      expect((mapped as AppSuccess<int>).value, 42);
    });

    test('map preserves a failure without invoking the transform', () {
      final error = AppError(
        code: AppErrorCode.invalidState,
        operation: 'app.bootstrap',
      );
      final AppResult<int> result = AppFailure<int>(error);
      var transformCalled = false;

      final mapped = result.map<String>((value) {
        transformCalled = true;
        return value.toString();
      });

      expect(transformCalled, isFalse);
      expect(mapped, isA<AppFailure<String>>());
      expect((mapped as AppFailure<String>).error, same(error));
    });

    test('fold invokes only the success callback for AppSuccess', () {
      const AppResult<int> result = AppSuccess<int>(7);
      var failureCalled = false;

      final output = result.fold<String>(
        onSuccess: (value) => 'value:$value',
        onFailure: (error) {
          failureCalled = true;
          return error.operation;
        },
      );

      expect(output, 'value:7');
      expect(failureCalled, isFalse);
    });

    test('fold invokes only the failure callback for AppFailure', () {
      final error = AppError(
        code: AppErrorCode.timeout,
        operation: 'catalog.load',
        retryable: true,
      );
      final AppResult<int> result = AppFailure<int>(error);
      var successCalled = false;

      final output = result.fold<String>(
        onSuccess: (value) {
          successCalled = true;
          return value.toString();
        },
        onFailure: (failure) => failure.operation,
      );

      expect(output, 'catalog.load');
      expect(successCalled, isFalse);
    });

    test('map safely changes the success value type', () {
      const AppResult<int> result = AppSuccess<int>(123);

      final AppResult<String> mapped = result.map(
        (value) => 'number:$value',
      );

      expect(mapped, isA<AppSuccess<String>>());
      expect((mapped as AppSuccess<String>).value, 'number:123');
    });

    test('a nullable null success is not confused with a failure', () {
      const AppResult<String?> result = AppSuccess<String?>(null);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect((result as AppSuccess<String?>).value, isNull);
    });
  });
}

import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppError', () {
    test('holds required values and safe defaults', () {
      final error = AppError(
        code: AppErrorCode.invalidArgument,
        operation: 'calculation.execute',
      );

      expect(error.code, AppErrorCode.invalidArgument);
      expect(error.operation, 'calculation.execute');
      expect(error.retryable, isFalse);
      expect(error.context, isEmpty);
      expect(error.safeMessage, isNull);
      expect(error.debugMessage, isNull);
      expect(error.causeType, isNull);
      expect(error.occurredAt, isNull);
    });

    test('holds optional safe diagnostic values', () {
      final occurredAt = DateTime.utc(2026, 9, 14, 12, 30);
      final error = AppError(
        code: AppErrorCode.databaseReadFailed,
        operation: 'database.read',
        retryable: true,
        context: const <String, Object?>{
          'schemaVersion': 2,
          'operationStep': 'loadStores',
        },
        safeMessage: 'Stored data could not be read.',
        debugMessage: 'Read operation failed.',
        causeType: 'DatabaseException',
        occurredAt: occurredAt,
      );

      expect(error.retryable, isTrue);
      expect(error.context['schemaVersion'], 2);
      expect(error.context['operationStep'], 'loadStores');
      expect(error.safeMessage, 'Stored data could not be read.');
      expect(error.debugMessage, 'Read operation failed.');
      expect(error.causeType, 'DatabaseException');
      expect(error.occurredAt, occurredAt);
    });

    test('defensively copies context', () {
      final source = <String, Object?>{'catalogVersion': 'v2'};
      final error = AppError(
        code: AppErrorCode.catalogValidationFailed,
        operation: 'catalog.validate',
        context: source,
      );

      source['catalogVersion'] = 'changed';

      expect(error.context['catalogVersion'], 'v2');
    });

    test('exposes context as an unmodifiable map', () {
      final error = AppError(
        code: AppErrorCode.migrationValidationFailed,
        operation: 'migration.validate',
        context: const <String, Object?>{'schemaVersion': 1},
      );

      expect(
        () => error.context['schemaVersion'] = 2,
        throwsUnsupportedError,
      );
    });

    test('toString contains only the approved summary fields', () {
      final error = AppError(
        code: AppErrorCode.backupValidationFailed,
        operation: 'backup.validate',
        retryable: false,
      );

      expect(
        error.toString(),
        'AppError('
        'code: backupValidationFailed, '
        'operation: backup.validate, '
        'retryable: false'
        ')',
      );
    });

    test('toString does not expose diagnostic or sensitive values', () {
      final error = AppError(
        code: AppErrorCode.backupReadFailed,
        operation: 'backup.import',
        context: const <String, Object?>{
          'token': 'secret-token',
          'rawBackup': 'private-backup-content',
        },
        safeMessage: 'Safe explanation',
        debugMessage: 'Developer-only details',
        causeType: 'FileSystemException',
        occurredAt: DateTime.utc(2026, 9, 14),
      );

      final text = error.toString();

      expect(text, isNot(contains('secret-token')));
      expect(text, isNot(contains('private-backup-content')));
      expect(text, isNot(contains('Safe explanation')));
      expect(text, isNot(contains('Developer-only details')));
      expect(text, isNot(contains('FileSystemException')));
      expect(text, isNot(contains('2026')));
    });
  });
}

import 'package:bestpay/application/catalog/typed_catalog_decoder.dart';
import 'package:bestpay/core/errors/app_error.dart';
import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/catalog_version.dart';
import 'package:bestpay/domain/catalog/catalog_snapshot.dart';
import 'package:bestpay/domain/catalog/models/typed_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TypedCatalogDecoder contract', () {
    test('accepts a CatalogSnapshot and returns a typed success', () {
      final catalog = _emptyCatalog();
      final expected = AppSuccess<TypedCatalog>(catalog);
      final decoder = _FakeTypedCatalogDecoder(expected);
      final snapshot = _snapshot();

      final result = decoder.decode(snapshot);

      expect(result, same(expected));
      expect(decoder.receivedSnapshot, same(snapshot));
      expect(result, isA<AppSuccess<TypedCatalog>>());
      expect((result as AppSuccess<TypedCatalog>).value, same(catalog));
    });

    test('can return an atomic structured failure', () {
      final error = AppError(
        code: AppErrorCode.catalogDecodeFailed,
        operation: 'typedCatalog.decode',
      );
      final expected = AppFailure<TypedCatalog>(error);
      final decoder = _FakeTypedCatalogDecoder(expected);
      final snapshot = _snapshot();

      final result = decoder.decode(snapshot);

      expect(result, same(expected));
      expect(decoder.receivedSnapshot, same(snapshot));
      expect(result, isA<AppFailure<TypedCatalog>>());
      expect((result as AppFailure<TypedCatalog>).error, same(error));
    });
  });
}

final class _FakeTypedCatalogDecoder implements TypedCatalogDecoder {
  _FakeTypedCatalogDecoder(this.result);

  final AppResult<TypedCatalog> result;
  CatalogSnapshot? receivedSnapshot;

  @override
  AppResult<TypedCatalog> decode(CatalogSnapshot snapshot) {
    receivedSnapshot = snapshot;
    return result;
  }
}

CatalogSnapshot _snapshot() {
  return CatalogSnapshot(
    schemaVersion: '1.0.0',
    catalogVersion: _catalogVersion('2026.09.21.1'),
    generatedAt: DateTime.utc(2026, 9, 21),
    documents: const <String, Object?>{},
  );
}

TypedCatalog _emptyCatalog() {
  return TypedCatalog(
    paymentInstruments: const [],
    paymentRoutes: const [],
    paymentModes: const [],
    fundingRelations: const [],
    merchants: const [],
    merchantGroups: const [],
    merchantCategories: const [],
    pointPrograms: const [],
    conditionDefinitions: const [],
    rewardRules: const [],
    sources: const [],
    idMigrations: const [],
  );
}

CatalogVersion _catalogVersion(String value) {
  final result = CatalogVersion.create(value);
  expect(result, isA<AppSuccess<CatalogVersion>>());
  return (result as AppSuccess<CatalogVersion>).value;
}

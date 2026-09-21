import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalog enum stable values', () {
    test('CatalogItemStatus values match the schema', () {
      expect(
        CatalogItemStatus.values.map((value) => value.value),
        <String>[
          'draft',
          'unverified',
          'active',
          'inactive',
          'deprecated',
          'superseded',
          'historical',
          'archived',
        ],
      );
    });

    test('PaymentModeType values match the schema', () {
      expect(
        PaymentModeType.values.map((value) => value.value),
        <String>[
          'credit',
          'debit',
          'pointPay',
          'addedCard',
          'prepaidBalance',
        ],
      );
    });

    test('ConditionVerificationMethod values match the schema', () {
      expect(
        ConditionVerificationMethod.values.map((value) => value.value),
        <String>[
          'userInput',
          'systemCalculated',
          'transactionDerived',
          'periodStateDerived',
          'officialAccountDerived',
          'manualDocumentCheck',
        ],
      );
    });

    test('ComparisonOperator values match the schema', () {
      expect(
        ComparisonOperator.values.map((value) => value.value),
        <String>[
          'equals',
          'notEquals',
          'greaterThan',
          'greaterThanOrEqual',
          'lessThan',
          'lessThanOrEqual',
          'in',
          'notIn',
        ],
      );
    });

    test('IdMigrationType values match the schema', () {
      expect(
        IdMigrationType.values.map((value) => value.value),
        <String>[
          'rename',
          'merge',
          'split',
          'remove',
        ],
      );
    });

    test('CatalogSourceType values match the schema', () {
      expect(
        CatalogSourceType.values.map((value) => value.value),
        <String>[
          'officialTerms',
          'officialFaq',
          'officialProductPage',
          'officialCampaignPage',
          'officialNewsRelease',
          'officialAppNotice',
          'secondaryArticle',
          'userReport',
        ],
      );
    });

    test('source status values match the schema', () {
      expect(
        CatalogSourceAccessStatus.values.map((value) => value.value),
        <String>[
          'accessible',
          'changed',
          'unavailable',
          'archived',
        ],
      );

      expect(
        CatalogSourceReliability.values.map((value) => value.value),
        <String>[
          'primary',
          'secondary',
          'userReported',
          'unverified',
        ],
      );
    });
  });
}

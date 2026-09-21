import 'dart:convert';

import 'package:bestpay/core/errors/app_error_code.dart';
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/core/value_objects/catalog_version.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/catalog/catalog_snapshot.dart';
import 'package:bestpay/domain/catalog/models/condition_models.dart';
import 'package:bestpay/domain/catalog/models/point_program_models.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:bestpay/domain/catalog/models/typed_catalog.dart';
import 'package:bestpay/infrastructure/catalog/json_typed_catalog_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const decoder = JsonTypedCatalogDecoder();

  group('JsonTypedCatalogDecoder', () {
    test('decodes all 12 documents atomically', () {
      final result = decoder.decode(_snapshot());

      expect(result, isA<AppSuccess<TypedCatalog>>());

      final catalog = (result as AppSuccess<TypedCatalog>).value;

      expect(catalog.paymentInstruments, hasLength(1));
      expect(catalog.paymentRoutes, hasLength(1));
      expect(catalog.paymentModes, hasLength(1));
      expect(catalog.fundingRelations, hasLength(1));
      expect(catalog.merchantGroups, hasLength(1));
      expect(catalog.merchants, hasLength(1));
      expect(catalog.merchantCategories, hasLength(1));
      expect(catalog.pointPrograms, hasLength(1));
      expect(catalog.conditionDefinitions, hasLength(1));
      expect(catalog.rewardRules, hasLength(1));
      expect(catalog.sources, hasLength(1));
      expect(catalog.idMigrations, hasLength(1));

      final instrument = catalog.paymentInstruments[_id('instrument_one')]!;
      expect(instrument.name, 'Instrument One');
      expect(instrument.annualFee.yen, 0);
      expect(instrument.partnerInstitutionName, isNull);

      final source = catalog.sources[_id('source_one')]!;
      expect(source.url, Uri.parse('https://example.com/source'));
      expect(source.publishedAt, isNull);
      expect(source.contentHash, 'a' * 64);

      final migration = catalog.idMigrations[_id('migration_one')]!;
      expect(migration.fromIds.single.value, 'old_instrument');
      expect(migration.toIds.single.value, 'instrument_one');
    });

    test('returns immutable typed indexes and model collections', () {
      final result = decoder.decode(_snapshot());
      final catalog = (result as AppSuccess<TypedCatalog>).value;

      expect(
        () => catalog.sources.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => catalog.paymentInstruments[_id('instrument_one')]!.notes
            .add('mutated'),
        throwsUnsupportedError,
      );
      expect(
        () => catalog
            .rewardRules[_id('reward_rule_one')]!.selectors.instrumentIds
            .add(_id('another_instrument')),
        throwsUnsupportedError,
      );
    });

    test('decodes point value and expiration variants', () {
      final variants = <Map<String, Object?>>[
        <String, Object?>{
          'valueDefinition': <String, Object?>{
            'valueType': 'fixed',
            'yenPerPoint': <String, Object?>{
              'numerator': 1,
              'denominator': 2,
            },
          },
          'expiration': <String, Object?>{
            'expirationType': 'fixedDate',
            'expiresOn': '2027-01-01',
          },
        },
        <String, Object?>{
          'valueDefinition': <String, Object?>{
            'valueType': 'variable',
          },
          'expiration': <String, Object?>{
            'expirationType': 'durationMonths',
            'months': 12,
          },
        },
        <String, Object?>{
          'valueDefinition': <String, Object?>{
            'valueType': 'unset',
          },
          'expiration': <String, Object?>{
            'expirationType': 'none',
          },
        },
        <String, Object?>{
          'valueDefinition': <String, Object?>{
            'valueType': 'fixed',
            'yenPerPoint': <String, Object?>{
              'numerator': 1,
              'denominator': 1,
            },
          },
          'expiration': <String, Object?>{
            'expirationType': 'unknown',
          },
        },
      ];

      final expectedValueTypes = <Type>[
        FixedPointValueDefinition,
        VariablePointValueDefinition,
        UnsetPointValueDefinition,
        FixedPointValueDefinition,
      ];
      final expectedExpirationTypes = <Type>[
        FixedDatePointExpiration,
        DurationMonthsPointExpiration,
        NoPointExpiration,
        UnknownPointExpiration,
      ];

      for (var index = 0; index < variants.length; index++) {
        final documents = _validDocuments();
        final pointProgram = _firstItem(documents, 'point_programs.json');
        pointProgram['valueDefinition'] = variants[index]['valueDefinition'];
        pointProgram['expiration'] = variants[index]['expiration'];

        final result = decoder.decode(_snapshot(documents));
        expect(result, isA<AppSuccess<TypedCatalog>>());

        final program = (result as AppSuccess<TypedCatalog>)
            .value
            .pointPrograms
            .values
            .single;

        expect(program.valueDefinition.runtimeType, expectedValueTypes[index]);
        expect(program.expiration.runtimeType, expectedExpirationTypes[index]);
      }
    });

    test('decodes every reward calculation variant', () {
      final variants = <Map<String, Object?>>[
        <String, Object?>{
          'calculationType': 'unitPoints',
          'amountUnitYen': 200,
          'pointsPerUnit': 1,
          'rounding': 'floor',
        },
        <String, Object?>{
          'calculationType': 'rateFraction',
          'numerator': 1,
          'denominator': 100,
          'rounding': 'halfToEven',
        },
        <String, Object?>{
          'calculationType': 'fixedPoints',
          'points': 10,
        },
        <String, Object?>{
          'calculationType': 'mirror',
          'sourceRuleId': 'source_rule',
          'multiplierNumerator': 2,
          'multiplierDenominator': 1,
          'inheritEligibility': true,
          'inheritExclusions': false,
          'useFinalSourceAmount': true,
        },
        <String, Object?>{
          'calculationType': 'thresholdBonus',
          'thresholdAmountYen': 1000,
          'bonusPoints': 100,
          'maxAwardsPerPeriod': 1,
        },
        <String, Object?>{
          'calculationType': 'tiered',
          'tiers': <Object?>[
            <String, Object?>{
              'minimumAmountYen': 0,
              'maximumAmountYenExclusive': null,
              'calculation': <String, Object?>{
                'calculationType': 'fixedPoints',
                'points': 5,
              },
            },
          ],
        },
        <String, Object?>{
          'calculationType': 'none',
        },
      ];

      final expectedTypes = <Type>[
        UnitPointsRewardCalculation,
        RateFractionRewardCalculation,
        FixedPointsRewardCalculation,
        MirrorRewardCalculation,
        ThresholdBonusRewardCalculation,
        TieredRewardCalculation,
        NoRewardCalculation,
      ];

      for (var index = 0; index < variants.length; index++) {
        final documents = _validDocuments();
        _firstItem(documents, 'reward_rules.json')['calculation'] =
            variants[index];

        final result = decoder.decode(_snapshot(documents));
        expect(result, isA<AppSuccess<TypedCatalog>>());

        final calculation = (result as AppSuccess<TypedCatalog>)
            .value
            .rewardRules
            .values
            .single
            .calculation;

        expect(calculation.runtimeType, expectedTypes[index]);
      }
    });

    test('decodes condition node and comparison value variants', () {
      final expressions = <Map<String, Object?>>[
        <String, Object?>{
          'nodeType': 'all',
          'children': <Object?>[
            <String, Object?>{
              'nodeType': 'condition',
              'conditionId': 'condition_one',
            },
          ],
        },
        <String, Object?>{
          'nodeType': 'any',
          'children': <Object?>[
            <String, Object?>{
              'nodeType': 'condition',
              'conditionId': 'condition_one',
            },
          ],
        },
        <String, Object?>{
          'nodeType': 'not',
          'child': <String, Object?>{
            'nodeType': 'condition',
            'conditionId': 'condition_one',
          },
        },
        <String, Object?>{
          'nodeType': 'comparison',
          'conditionId': 'condition_one',
          'comparisonOperator': 'equals',
          'value': 'gold',
        },
        <String, Object?>{
          'nodeType': 'comparison',
          'conditionId': 'condition_one',
          'comparisonOperator': 'greaterThan',
          'value': 10,
        },
        <String, Object?>{
          'nodeType': 'comparison',
          'conditionId': 'condition_one',
          'comparisonOperator': 'equals',
          'value': true,
        },
        <String, Object?>{
          'nodeType': 'comparison',
          'conditionId': 'condition_one',
          'comparisonOperator': 'equals',
          'value': null,
        },
        <String, Object?>{
          'nodeType': 'comparison',
          'conditionId': 'condition_one',
          'comparisonOperator': 'equals',
          'value': <String, Object?>{
            'numerator': 1,
            'denominator': 2,
          },
        },
        <String, Object?>{
          'nodeType': 'comparison',
          'conditionId': 'condition_one',
          'comparisonOperator': 'in',
          'value': <Object?>['gold', 10, true],
        },
      ];

      final expectedExpressionTypes = <Type>[
        AllConditionExpression,
        AnyConditionExpression,
        NotConditionExpression,
        ComparisonConditionExpression,
        ComparisonConditionExpression,
        ComparisonConditionExpression,
        ComparisonConditionExpression,
        ComparisonConditionExpression,
        ComparisonConditionExpression,
      ];

      final expectedValueTypes = <Type?>[
        null,
        null,
        null,
        StringConditionComparisonValue,
        IntegerConditionComparisonValue,
        BooleanConditionComparisonValue,
        NullConditionComparisonValue,
        RationalConditionComparisonValue,
        ListConditionComparisonValue,
      ];

      for (var index = 0; index < expressions.length; index++) {
        final documents = _validDocuments();
        _firstItem(documents, 'reward_rules.json')['conditionExpression'] =
            expressions[index];

        final result = decoder.decode(_snapshot(documents));
        expect(result, isA<AppSuccess<TypedCatalog>>());

        final expression = (result as AppSuccess<TypedCatalog>)
            .value
            .rewardRules
            .values
            .single
            .conditionExpression!;

        expect(expression.runtimeType, expectedExpressionTypes[index]);

        if (expression is ComparisonConditionExpression) {
          expect(expression.value.runtimeType, expectedValueTypes[index]);
        }
      }
    });

    test('rejects condition depth greater than 10', () {
      Object expression = <String, Object?>{
        'nodeType': 'condition',
        'conditionId': 'condition_one',
      };

      for (var index = 0; index < 10; index++) {
        expression = <String, Object?>{
          'nodeType': 'not',
          'child': expression,
        };
      }

      final documents = _validDocuments();
      _firstItem(documents, 'reward_rules.json')['conditionExpression'] =
          expression;

      _expectDecodeFailure(decoder.decode(_snapshot(documents)));
    });

    test('rejects condition trees exceeding 100 nodes', () {
      final documents = _validDocuments();
      _firstItem(documents, 'reward_rules.json')['conditionExpression'] =
          <String, Object?>{
        'nodeType': 'all',
        'children': List<Object?>.generate(
          100,
          (_) => <String, Object?>{
            'nodeType': 'condition',
            'conditionId': 'condition_one',
          },
        ),
      };

      _expectDecodeFailure(decoder.decode(_snapshot(documents)));
    });

    test('fails atomically when a required document is missing', () {
      final documents = _validDocuments()..remove('merchant_categories.json');

      _expectDecodeFailure(decoder.decode(_snapshot(documents)));
    });

    test('fails atomically for invalid primitive and enum values', () {
      final invalidIdDocuments = _validDocuments();
      _firstItem(invalidIdDocuments, 'merchants.json')['id'] = 'INVALID';

      _expectDecodeFailure(decoder.decode(_snapshot(invalidIdDocuments)));

      final invalidEnumDocuments = _validDocuments();
      _firstItem(invalidEnumDocuments, 'payment_modes.json')['modeType'] =
          'futureMode';

      _expectDecodeFailure(decoder.decode(_snapshot(invalidEnumDocuments)));

      final invalidDateDocuments = _validDocuments();
      _firstItem(
        invalidDateDocuments,
        'payment_routes.json',
      )['validFrom'] = '2026-02-30';

      _expectDecodeFailure(decoder.decode(_snapshot(invalidDateDocuments)));
    });

    test('fails atomically for invalid rational and validity period', () {
      final invalidRationalDocuments = _validDocuments();
      final program =
          _firstItem(invalidRationalDocuments, 'point_programs.json');
      program['valueDefinition'] = <String, Object?>{
        'valueType': 'fixed',
        'yenPerPoint': <String, Object?>{
          'numerator': 1,
          'denominator': 0,
        },
      };

      _expectDecodeFailure(decoder.decode(_snapshot(invalidRationalDocuments)));

      final invalidPeriodDocuments = _validDocuments();
      final route = _firstItem(invalidPeriodDocuments, 'payment_routes.json');
      route['validFrom'] = '2027-01-01';
      route['validUntilExclusive'] = '2026-01-01';

      _expectDecodeFailure(decoder.decode(_snapshot(invalidPeriodDocuments)));
    });

    test('fails atomically for duplicate IDs in one catalog', () {
      final documents = _validDocuments();
      final source = _firstItem(documents, 'sources.json');
      final sourceDocument = documents['sources.json']! as Map<String, Object?>;
      final items = sourceDocument['items']! as List<Object?>;
      items.add(_deepCopy(source));

      _expectDecodeFailure(decoder.decode(_snapshot(documents)));
    });

    test('does not expose exception text or raw document values', () {
      final documents = _validDocuments();
      _firstItem(documents, 'sources.json')['url'] = 'relative/path';

      final result = decoder.decode(_snapshot(documents));

      expect(result, isA<AppFailure<TypedCatalog>>());
      final error = (result as AppFailure<TypedCatalog>).error;

      expect(error.code, AppErrorCode.catalogDecodeFailed);
      expect(error.operation, 'typedCatalog.decode');
      expect(error.context['catalogVersion'], '2026.09.21.1');
      expect(error.context.containsKey('documents'), isFalse);
      expect(error.safeMessage, isNull);
      expect(error.debugMessage, isNull);
      expect(error.causeType, isNotEmpty);
    });
  });
}

void _expectDecodeFailure(AppResult<TypedCatalog> result) {
  expect(result, isA<AppFailure<TypedCatalog>>());

  final error = (result as AppFailure<TypedCatalog>).error;
  expect(error.code, AppErrorCode.catalogDecodeFailed);
  expect(error.operation, 'typedCatalog.decode');
  expect(error.context, <String, Object?>{
    'catalogVersion': '2026.09.21.1',
  });
}

CatalogSnapshot _snapshot([
  Map<String, Object?>? documents,
]) {
  final versionResult = CatalogVersion.create('2026.09.21.1');
  final version = (versionResult as AppSuccess<CatalogVersion>).value;

  return CatalogSnapshot(
    schemaVersion: '1.0.0',
    catalogVersion: version,
    generatedAt: DateTime.utc(2026, 9, 21),
    documents: documents ?? _validDocuments(),
  );
}

StableId _id(String value) {
  return (StableId.create(value) as AppSuccess<StableId>).value;
}

Map<String, Object?> _validDocuments() {
  const validFrom = '2026-01-01';
  const lastVerifiedAt = '2026-09-21';

  Map<String, Object?> document(Map<String, Object?> item) {
    return <String, Object?>{
      'items': <Object?>[item],
    };
  }

  final emptySelectors = <String, Object?>{
    'instrumentIds': <Object?>[],
    'modeIds': <Object?>[],
    'routeIds': <Object?>[],
    'fundingRelationIds': <Object?>[],
    'merchantIds': <Object?>[],
    'merchantGroupIds': <Object?>[],
    'categoryIds': <Object?>[],
    'brandIds': <Object?>[],
    'locationIds': <Object?>[],
    'transactionTags': <Object?>[],
  };

  return <String, Object?>{
    'payment_instruments.json': document(<String, Object?>{
      'id': 'instrument_one',
      'name': 'Instrument One',
      'shortName': 'One',
      'instrumentType': 'creditCard',
      'issuerName': 'Issuer',
      'partnerInstitutionName': null,
      'availableBrandIds': <Object?>['brand_one'],
      'annualFee': 0,
      'supportedModeIds': <Object?>['mode_one'],
      'supportedRouteIds': <Object?>['route_one'],
      'validFrom': validFrom,
      'validUntilExclusive': null,
      'status': 'active',
      'sourceIds': <Object?>['source_one'],
      'lastVerifiedAt': lastVerifiedAt,
      'displayClaims': <Object?>['Claim'],
      'tags': <Object?>['tag_one'],
      'notes': <Object?>[],
    }),
    'payment_routes.json': document(<String, Object?>{
      'id': 'route_one',
      'name': 'Route One',
      'routeType': 'contactless',
      'brandIds': <Object?>['brand_one'],
      'deviceRequirement': null,
      'supportedInstrumentIds': <Object?>['instrument_one'],
      'validFrom': validFrom,
      'validUntilExclusive': null,
      'status': 'active',
      'sourceIds': <Object?>['source_one'],
      'notes': <Object?>[],
    }),
    'payment_modes.json': document(<String, Object?>{
      'id': 'mode_one',
      'instrumentId': 'instrument_one',
      'name': 'Credit',
      'modeType': 'credit',
      'supportedRouteIds': <Object?>['route_one'],
      'validFrom': validFrom,
      'validUntilExclusive': null,
      'status': 'active',
      'sourceIds': <Object?>['source_one'],
      'notes': <Object?>[],
    }),
    'funding_relations.json': document(<String, Object?>{
      'id': 'funding_one',
      'sourceInstrumentId': 'instrument_one',
      'destinationInstrumentId': 'instrument_two',
      'relationType': 'charge',
      'validFrom': validFrom,
      'validUntilExclusive': null,
      'status': 'active',
      'sourceIds': <Object?>['source_one'],
      'notes': <Object?>[],
    }),
    'merchant_groups.json': document(<String, Object?>{
      'id': 'merchant_group_one',
      'name': 'Merchant Group One',
      'description': '',
      'status': 'active',
      'sourceIds': <Object?>['source_one'],
      'notes': <Object?>[],
    }),
    'merchants.json': document(<String, Object?>{
      'id': 'merchant_one',
      'name': 'Merchant One',
      'merchantGroupIds': <Object?>['merchant_group_one'],
      'categoryIds': <Object?>['category_one'],
      'locationIds': <Object?>['location_one'],
      'status': 'active',
      'sourceIds': <Object?>['source_one'],
      'notes': <Object?>[],
    }),
    'merchant_categories.json': document(<String, Object?>{
      'id': 'category_one',
      'name': 'Category One',
      'parentCategoryId': null,
      'status': 'active',
      'sourceIds': <Object?>['source_one'],
      'notes': <Object?>[],
    }),
    'point_programs.json': document(<String, Object?>{
      'id': 'point_program_one',
      'name': 'Point Program One',
      'issuerName': 'Issuer',
      'unitName': 'point',
      'valueDefinition': <String, Object?>{
        'valueType': 'fixed',
        'yenPerPoint': <String, Object?>{
          'numerator': 1,
          'denominator': 1,
        },
      },
      'expiration': <String, Object?>{
        'expirationType': 'none',
      },
      'status': 'active',
      'sourceIds': <Object?>['source_one'],
      'lastVerifiedAt': lastVerifiedAt,
      'notes': <Object?>[],
    }),
    'condition_definitions.json': document(<String, Object?>{
      'id': 'condition_one',
      'name': 'Condition One',
      'description': '',
      'valueType': 'boolean',
      'defaultState': 'unknown',
      'verificationMethod': 'userInput',
      'scope': 'transaction',
      'sensitivity': 'normal',
      'validFrom': validFrom,
      'validUntilExclusive': null,
      'status': 'active',
      'sourceIds': <Object?>['source_one'],
      'notes': <Object?>[],
    }),
    'reward_rules.json': document(<String, Object?>{
      'id': 'reward_rule_one',
      'name': 'Reward Rule One',
      'description': '',
      'ruleKind': 'baseReward',
      'selectors': _deepCopy(emptySelectors),
      'exclusions': _deepCopy(emptySelectors),
      'conditionExpression': null,
      'calculation': <String, Object?>{
        'calculationType': 'none',
      },
      'outputPointProgramId': null,
      'aggregation': <String, Object?>{
        'scope': 'transaction',
        'aggregationKey': null,
        'periodMinimumEligibleSpendYen': 0,
        'conditionEvaluationTiming': 'transaction',
        'incrementalAward': false,
      },
      'stacking': <String, Object?>{
        'policy': 'stackable',
        'exclusiveGroupId': null,
        'replacesRuleIds': <Object?>[],
        'suppressesRuleIds': <Object?>[],
        'suppressesTags': <Object?>[],
        'dependsOnRuleIds': <Object?>[],
        'applicationOrder': 0,
      },
      'cap': null,
      'validFrom': validFrom,
      'validUntilExclusive': null,
      'dateBasis': 'transactionDate',
      'timezone': 'Asia/Tokyo',
      'displayClaim': null,
      'sourceIds': <Object?>['source_one'],
      'lastVerifiedAt': lastVerifiedAt,
      'status': 'active',
      'priority': 0,
      'tags': <Object?>[],
      'notes': <Object?>[],
    }),
    'sources.json': document(<String, Object?>{
      'id': 'source_one',
      'title': 'Official source',
      'url': 'https://example.com/source',
      'publisher': 'Example',
      'sourceType': 'officialProductPage',
      'publishedAt': null,
      'lastVerifiedAt': lastVerifiedAt,
      'accessStatus': 'accessible',
      'reliability': 'primary',
      'relevantSections': <Object?>['Rewards'],
      'summary': '',
      'contentHash': 'a' * 64,
      'notes': <Object?>[],
    }),
    'id_migrations.json': document(<String, Object?>{
      'id': 'migration_one',
      'entityType': 'paymentInstrument',
      'migrationType': 'rename',
      'fromIds': <Object?>['old_instrument'],
      'toIds': <Object?>['instrument_one'],
      'evidenceSourceIds': <Object?>['source_one'],
      'needsReview': false,
      'effectiveFrom': validFrom,
      'notes': <Object?>[],
    }),
  };
}

Map<String, Object?> _firstItem(
  Map<String, Object?> documents,
  String fileName,
) {
  final document = documents[fileName]! as Map<String, Object?>;
  final items = document['items']! as List<Object?>;
  return items.first! as Map<String, Object?>;
}

T _deepCopy<T>(T value) {
  return jsonDecode(jsonEncode(value)) as T;
}

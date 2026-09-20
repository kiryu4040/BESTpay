import 'package:bestpay/domain/catalog/catalog_integrity_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = CatalogIntegrityValidator();

  Map<String, Object?> document(
    List<Map<String, Object?>> items,
  ) {
    return <String, Object?>{'items': items};
  }

  Map<String, Object?> emptyDocuments() {
    return <String, Object?>{
      'payment_instruments.json': document([]),
      'payment_routes.json': document([]),
      'payment_modes.json': document([]),
      'funding_relations.json': document([]),
      'merchant_groups.json': document([]),
      'merchants.json': document([]),
      'merchant_categories.json': document([]),
      'point_programs.json': document([]),
      'condition_definitions.json': document([]),
      'reward_rules.json': document([]),
      'sources.json': document([]),
      'id_migrations.json': document([]),
    };
  }

  test('accepts known cross-catalog references', () {
    final documents = emptyDocuments();

    documents['sources.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'source_001',
          'reliability': 'primary',
        },
      ],
    );

    documents['payment_instruments.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'instrument_001',
          'supportedModeIds': <String>['mode_001'],
          'supportedRouteIds': <String>['route_001'],
          'sourceIds': <String>['source_001'],
        },
      ],
    );

    documents['payment_modes.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'mode_001',
          'instrumentId': 'instrument_001',
          'supportedRouteIds': <String>['route_001'],
          'sourceIds': <String>['source_001'],
        },
      ],
    );

    documents['payment_routes.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'route_001',
          'supportedInstrumentIds': <String>['instrument_001'],
          'brandIds': <String>['unmodelled_brand'],
          'sourceIds': <String>['source_001'],
        },
      ],
    );

    expect(validator.validate(documents), isEmpty);
  });

  test('reports CAT-E001 for a missing modeled reference', () {
    final documents = emptyDocuments();

    documents['payment_modes.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'mode_001',
          'instrumentId': 'missing_instrument',
        },
      ],
    );

    final diagnostics = validator.validate(documents);

    expect(
      diagnostics.map((item) => item.code.value),
      contains('CAT-E001'),
    );
    expect(
      diagnostics.single.context['referencedId'],
      'missing_instrument',
    );
  });

  test('does not check IDs whose catalogs are not modeled', () {
    final documents = emptyDocuments();

    documents['payment_routes.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'route_001',
          'brandIds': <String>['unknown_brand'],
        },
      ],
    );

    documents['merchants.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'merchant_001',
          'locationIds': <String>['unknown_location'],
        },
      ],
    );

    expect(validator.validate(documents), isEmpty);
  });

  test('reports CAT-E006 for missing mirror source rule', () {
    final documents = emptyDocuments();

    documents['reward_rules.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'rule_001',
          'status': 'draft',
          'calculation': <String, Object?>{
            'calculationType': 'mirror',
            'sourceRuleId': 'missing_rule',
          },
        },
      ],
    );

    final diagnostics = validator.validate(documents);

    expect(
      diagnostics.map((item) => item.code.value),
      contains('CAT-E006'),
    );
  });

  test('reports CAT-E008 for active rule without primary source', () {
    final documents = emptyDocuments();

    documents['sources.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'source_001',
          'reliability': 'secondary',
        },
      ],
    );

    documents['reward_rules.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'rule_001',
          'status': 'active',
          'sourceIds': <String>['source_001'],
        },
      ],
    );

    final diagnostics = validator.validate(documents);

    expect(
      diagnostics.map((item) => item.code.value),
      contains('CAT-E008'),
    );
  });

  test('checks nested ConditionExpression references', () {
    final documents = emptyDocuments();

    documents['reward_rules.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'rule_001',
          'status': 'draft',
          'conditionExpression': <String, Object?>{
            'nodeType': 'all',
            'children': <Object?>[
              <String, Object?>{
                'nodeType': 'condition',
                'conditionId': 'missing_condition',
              },
            ],
          },
        },
      ],
    );

    final diagnostics = validator.validate(documents);

    expect(
      diagnostics.map((item) => item.code.value),
      contains('CAT-E001'),
    );
    expect(
      diagnostics.any(
        (item) => item.context['referencedId'] == 'missing_condition',
      ),
      isTrue,
    );
  });
  test('reports CAT-E007 for a RewardRule mirror cycle', () {
    final documents = emptyDocuments();

    documents['reward_rules.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'rule_001',
          'status': 'draft',
          'calculation': <String, Object?>{
            'calculationType': 'mirror',
            'sourceRuleId': 'rule_002',
          },
        },
        <String, Object?>{
          'id': 'rule_002',
          'status': 'draft',
          'calculation': <String, Object?>{
            'calculationType': 'mirror',
            'sourceRuleId': 'rule_001',
          },
        },
      ],
    );

    final diagnostics = validator.validate(documents);

    expect(
      diagnostics.map((item) => item.code.value),
      contains('CAT-E007'),
    );
  });

  test('reports CAT-F006 for a MerchantCategory parent cycle', () {
    final documents = emptyDocuments();

    documents['merchant_categories.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'category_001',
          'parentCategoryId': 'category_002',
        },
        <String, Object?>{
          'id': 'category_002',
          'parentCategoryId': 'category_001',
        },
      ],
    );

    final diagnostics = validator.validate(documents);

    final cycleDiagnostic = diagnostics.firstWhere(
      (item) =>
          item.code.value == 'CAT-F006' &&
          item.context['cycleType'] == 'merchantCategoryParent',
    );

    expect(cycleDiagnostic.blocksPublication, isTrue);
  });

  test('reports CAT-F006 for an ID migration cycle', () {
    final documents = emptyDocuments();

    documents['id_migrations.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'migration_001',
          'entityType': 'paymentInstrument',
          'fromIds': <String>['instrument_001'],
          'toIds': <String>['instrument_002'],
        },
        <String, Object?>{
          'id': 'migration_002',
          'entityType': 'paymentInstrument',
          'fromIds': <String>['instrument_002'],
          'toIds': <String>['instrument_001'],
        },
      ],
    );

    final diagnostics = validator.validate(documents);

    final cycleDiagnostic = diagnostics.firstWhere(
      (item) =>
          item.code.value == 'CAT-F006' &&
          item.context['cycleType'] == 'idMigration',
    );

    expect(
      cycleDiagnostic.context['entityType'],
      'paymentInstrument',
    );
  });

  test('does not treat FundingRelation cycles as prohibited', () {
    final documents = emptyDocuments();

    documents['payment_instruments.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{'id': 'instrument_001'},
        <String, Object?>{'id': 'instrument_002'},
      ],
    );

    documents['funding_relations.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'funding_001',
          'sourceInstrumentId': 'instrument_001',
          'destinationInstrumentId': 'instrument_002',
        },
        <String, Object?>{
          'id': 'funding_002',
          'sourceInstrumentId': 'instrument_002',
          'destinationInstrumentId': 'instrument_001',
        },
      ],
    );

    expect(validator.validate(documents), isEmpty);
  });

  test('detects a self-referencing cycle', () {
    final documents = emptyDocuments();

    documents['merchant_categories.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'category_001',
          'parentCategoryId': 'category_001',
        },
      ],
    );

    final diagnostics = validator.validate(documents);

    expect(
      diagnostics.map((item) => item.code.value),
      contains('CAT-F006'),
    );
  });

  test('reports CAT-E002 when a validity period starts after it ends', () {
    final documents = emptyDocuments();

    documents['reward_rules.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'rule_001',
          'status': 'draft',
          'validFrom': '2026-09-20',
          'validUntilExclusive': '2026-09-19',
        },
      ],
    );

    final diagnostics = validator.validate(documents);

    final diagnostic = diagnostics.singleWhere(
      (item) => item.code.value == 'CAT-E002',
    );

    expect(diagnostic.context['reason'], 'startAfterEnd');
    expect(diagnostic.blocksPublication, isTrue);
  });

  test('reports CAT-E002 for an empty active validity period', () {
    final documents = emptyDocuments();

    documents['sources.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'source_001',
          'reliability': 'primary',
        },
      ],
    );

    documents['reward_rules.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'rule_001',
          'status': 'active',
          'sourceIds': <String>['source_001'],
          'validFrom': '2026-09-19',
          'validUntilExclusive': '2026-09-19',
        },
      ],
    );

    final diagnostics = validator.validate(documents);

    final diagnostic = diagnostics.singleWhere(
      (item) => item.code.value == 'CAT-E002',
    );

    expect(diagnostic.context['reason'], 'activeEmptyInterval');
  });

  test('allows an empty validity period for a non-active item', () {
    final documents = emptyDocuments();

    documents['reward_rules.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'rule_001',
          'status': 'draft',
          'validFrom': '2026-09-19',
          'validUntilExclusive': '2026-09-19',
        },
      ],
    );

    expect(validator.validate(documents), isEmpty);
  });

  test('allows ConditionExpression at depth ten', () {
    Object expressionAtDepth(int depth) {
      Object expression = <String, Object?>{
        'nodeType': 'condition',
        'conditionId': 'condition_001',
      };

      for (var level = 1; level < depth; level++) {
        expression = <String, Object?>{
          'nodeType': 'not',
          'child': expression,
        };
      }

      return expression;
    }

    final documents = emptyDocuments();
    documents['condition_definitions.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{'id': 'condition_001'},
      ],
    );
    documents['reward_rules.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'rule_001',
          'status': 'draft',
          'conditionExpression': expressionAtDepth(10),
        },
      ],
    );

    expect(validator.validate(documents), isEmpty);
  });

  test('reports CAT-E013 at ConditionExpression depth eleven', () {
    Object expressionAtDepth(int depth) {
      Object expression = <String, Object?>{
        'nodeType': 'condition',
        'conditionId': 'condition_001',
      };

      for (var level = 1; level < depth; level++) {
        expression = <String, Object?>{
          'nodeType': 'not',
          'child': expression,
        };
      }

      return expression;
    }

    final documents = emptyDocuments();
    documents['condition_definitions.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{'id': 'condition_001'},
      ],
    );
    documents['reward_rules.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'rule_001',
          'status': 'draft',
          'conditionExpression': expressionAtDepth(11),
        },
      ],
    );

    final diagnostics = validator.validate(documents);
    final diagnostic = diagnostics.singleWhere(
      (item) => item.code.value == 'CAT-E013',
    );

    expect(diagnostic.context['maximumDepth'], 11);
    expect(diagnostic.context['nodeCount'], 11);
  });

  test('allows ConditionExpression with one hundred nodes', () {
    final documents = emptyDocuments();

    documents['condition_definitions.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{'id': 'condition_001'},
      ],
    );

    documents['reward_rules.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'rule_001',
          'status': 'draft',
          'conditionExpression': <String, Object?>{
            'nodeType': 'all',
            'children': List<Object?>.generate(
              99,
              (_) => <String, Object?>{
                'nodeType': 'condition',
                'conditionId': 'condition_001',
              },
            ),
          },
        },
      ],
    );

    expect(validator.validate(documents), isEmpty);
  });

  test('reports CAT-E013 with one hundred and one nodes', () {
    final documents = emptyDocuments();

    documents['condition_definitions.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{'id': 'condition_001'},
      ],
    );

    documents['reward_rules.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'rule_001',
          'status': 'draft',
          'conditionExpression': <String, Object?>{
            'nodeType': 'all',
            'children': List<Object?>.generate(
              100,
              (_) => <String, Object?>{
                'nodeType': 'condition',
                'conditionId': 'condition_001',
              },
            ),
          },
        },
      ],
    );

    final diagnostics = validator.validate(documents);
    final diagnostic = diagnostics.singleWhere(
      (item) => item.code.value == 'CAT-E013',
    );

    expect(diagnostic.context['nodeCount'], 101);
    expect(diagnostic.context['maximumAllowedNodeCount'], 100);
  });

  test('handles a deeply nested ConditionExpression without recursion', () {
    Object expression = <String, Object?>{
      'nodeType': 'condition',
      'conditionId': 'condition_001',
    };

    for (var level = 1; level < 2000; level++) {
      expression = <String, Object?>{
        'nodeType': 'not',
        'child': expression,
      };
    }

    final documents = emptyDocuments();
    documents['condition_definitions.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{'id': 'condition_001'},
      ],
    );
    documents['reward_rules.json'] = document(
      <Map<String, Object?>>[
        <String, Object?>{
          'id': 'rule_001',
          'status': 'draft',
          'conditionExpression': expression,
        },
      ],
    );

    final diagnostics = validator.validate(documents);

    expect(
      diagnostics.where((item) => item.code.value == 'CAT-E013'),
      hasLength(1),
    );
  });

  test('detects a long graph cycle without recursive traversal', () {
    final documents = emptyDocuments();
    const categoryCount = 2000;

    documents['merchant_categories.json'] = document(
      List<Map<String, Object?>>.generate(
        categoryCount,
        (index) => <String, Object?>{
          'id': 'category_${index.toString().padLeft(4, '0')}',
          'parentCategoryId':
              'category_${((index + 1) % categoryCount).toString().padLeft(4, '0')}',
        },
      ),
    );

    final diagnostics = validator.validate(documents);

    expect(
      diagnostics.where(
        (item) =>
            item.code.value == 'CAT-F006' &&
            item.context['cycleType'] == 'merchantCategoryParent',
      ),
      hasLength(1),
    );
  });
}

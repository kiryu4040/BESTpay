import 'catalog_diagnostic.dart';
import 'catalog_diagnostic_code.dart';

/// Validates references between the twelve decoded catalog documents.
///
/// References to catalogs that do not exist in PR-06, including brand,
/// location, tag, aggregation-key, scope-key, and exclusive-group IDs, are
/// intentionally not checked for existence.
final class CatalogIntegrityValidator {
  const CatalogIntegrityValidator();

  List<CatalogDiagnostic> validate(
    Map<String, Object?> documents,
  ) {
    final diagnostics = <CatalogDiagnostic>[];
    final idsByFile = <String, Set<String>>{};

    for (final fileName in _catalogFiles) {
      idsByFile[fileName] = _items(documents, fileName)
          .map((item) => item['id'])
          .whereType<String>()
          .toSet();
    }

    final sourceItems = <String, Map<String, Object?>>{
      for (final item in _items(documents, 'sources.json'))
        if (item['id'] is String) item['id']! as String: item,
    };

    _validateSourceReferences(
      documents,
      sourceItems.keys.toSet(),
      diagnostics,
    );

    _validatePaymentInstrumentReferences(
      documents,
      idsByFile,
      diagnostics,
    );
    _validatePaymentModeReferences(
      documents,
      idsByFile,
      diagnostics,
    );
    _validatePaymentRouteReferences(
      documents,
      idsByFile,
      diagnostics,
    );
    _validateFundingRelationReferences(
      documents,
      idsByFile,
      diagnostics,
    );
    _validateMerchantReferences(
      documents,
      idsByFile,
      diagnostics,
    );
    _validateMerchantCategoryReferences(
      documents,
      idsByFile,
      diagnostics,
    );
    _validateRewardRuleReferences(
      documents,
      idsByFile,
      sourceItems,
      diagnostics,
    );

    _validateValidityPeriods(
      documents,
      diagnostics,
    );
    _validateConditionExpressionLimits(
      documents,
      diagnostics,
    );

    _validateRewardRuleMirrorCycles(
      documents,
      diagnostics,
    );
    _validateMerchantCategoryCycles(
      documents,
      diagnostics,
    );
    _validateIdMigrationCycles(
      documents,
      diagnostics,
    );

    return List<CatalogDiagnostic>.unmodifiable(diagnostics);
  }

  void _validateSourceReferences(
    Map<String, Object?> documents,
    Set<String> sourceIds,
    List<CatalogDiagnostic> diagnostics,
  ) {
    for (final fileName in _catalogFiles) {
      final items = _items(documents, fileName);

      for (var index = 0; index < items.length; index++) {
        final item = items[index];

        _checkListReferences(
          value: item['sourceIds'],
          targetIds: sourceIds,
          fileName: fileName,
          itemIndex: index,
          fieldName: 'sourceIds',
          diagnostics: diagnostics,
        );

        _checkListReferences(
          value: item['evidenceSourceIds'],
          targetIds: sourceIds,
          fileName: fileName,
          itemIndex: index,
          fieldName: 'evidenceSourceIds',
          diagnostics: diagnostics,
        );
      }
    }
  }

  void _validatePaymentInstrumentReferences(
    Map<String, Object?> documents,
    Map<String, Set<String>> idsByFile,
    List<CatalogDiagnostic> diagnostics,
  ) {
    final items = _items(documents, 'payment_instruments.json');

    for (var index = 0; index < items.length; index++) {
      _checkListReferences(
        value: items[index]['supportedModeIds'],
        targetIds: idsByFile['payment_modes.json']!,
        fileName: 'payment_instruments.json',
        itemIndex: index,
        fieldName: 'supportedModeIds',
        diagnostics: diagnostics,
      );

      _checkListReferences(
        value: items[index]['supportedRouteIds'],
        targetIds: idsByFile['payment_routes.json']!,
        fileName: 'payment_instruments.json',
        itemIndex: index,
        fieldName: 'supportedRouteIds',
        diagnostics: diagnostics,
      );
    }
  }

  void _validatePaymentModeReferences(
    Map<String, Object?> documents,
    Map<String, Set<String>> idsByFile,
    List<CatalogDiagnostic> diagnostics,
  ) {
    final items = _items(documents, 'payment_modes.json');

    for (var index = 0; index < items.length; index++) {
      _checkReference(
        value: items[index]['instrumentId'],
        targetIds: idsByFile['payment_instruments.json']!,
        fileName: 'payment_modes.json',
        itemIndex: index,
        fieldName: 'instrumentId',
        diagnostics: diagnostics,
      );

      _checkListReferences(
        value: items[index]['supportedRouteIds'],
        targetIds: idsByFile['payment_routes.json']!,
        fileName: 'payment_modes.json',
        itemIndex: index,
        fieldName: 'supportedRouteIds',
        diagnostics: diagnostics,
      );
    }
  }

  void _validatePaymentRouteReferences(
    Map<String, Object?> documents,
    Map<String, Set<String>> idsByFile,
    List<CatalogDiagnostic> diagnostics,
  ) {
    final items = _items(documents, 'payment_routes.json');

    for (var index = 0; index < items.length; index++) {
      _checkListReferences(
        value: items[index]['supportedInstrumentIds'],
        targetIds: idsByFile['payment_instruments.json']!,
        fileName: 'payment_routes.json',
        itemIndex: index,
        fieldName: 'supportedInstrumentIds',
        diagnostics: diagnostics,
      );
    }
  }

  void _validateFundingRelationReferences(
    Map<String, Object?> documents,
    Map<String, Set<String>> idsByFile,
    List<CatalogDiagnostic> diagnostics,
  ) {
    final items = _items(documents, 'funding_relations.json');
    final instrumentIds = idsByFile['payment_instruments.json']!;

    for (var index = 0; index < items.length; index++) {
      _checkReference(
        value: items[index]['sourceInstrumentId'],
        targetIds: instrumentIds,
        fileName: 'funding_relations.json',
        itemIndex: index,
        fieldName: 'sourceInstrumentId',
        diagnostics: diagnostics,
      );
      _checkReference(
        value: items[index]['destinationInstrumentId'],
        targetIds: instrumentIds,
        fileName: 'funding_relations.json',
        itemIndex: index,
        fieldName: 'destinationInstrumentId',
        diagnostics: diagnostics,
      );
    }
  }

  void _validateMerchantReferences(
    Map<String, Object?> documents,
    Map<String, Set<String>> idsByFile,
    List<CatalogDiagnostic> diagnostics,
  ) {
    final items = _items(documents, 'merchants.json');

    for (var index = 0; index < items.length; index++) {
      _checkListReferences(
        value: items[index]['merchantGroupIds'],
        targetIds: idsByFile['merchant_groups.json']!,
        fileName: 'merchants.json',
        itemIndex: index,
        fieldName: 'merchantGroupIds',
        diagnostics: diagnostics,
      );
      _checkListReferences(
        value: items[index]['categoryIds'],
        targetIds: idsByFile['merchant_categories.json']!,
        fileName: 'merchants.json',
        itemIndex: index,
        fieldName: 'categoryIds',
        diagnostics: diagnostics,
      );
    }
  }

  void _validateMerchantCategoryReferences(
    Map<String, Object?> documents,
    Map<String, Set<String>> idsByFile,
    List<CatalogDiagnostic> diagnostics,
  ) {
    final items = _items(documents, 'merchant_categories.json');

    for (var index = 0; index < items.length; index++) {
      _checkReference(
        value: items[index]['parentCategoryId'],
        targetIds: idsByFile['merchant_categories.json']!,
        fileName: 'merchant_categories.json',
        itemIndex: index,
        fieldName: 'parentCategoryId',
        diagnostics: diagnostics,
      );
    }
  }

  void _validateRewardRuleReferences(
    Map<String, Object?> documents,
    Map<String, Set<String>> idsByFile,
    Map<String, Map<String, Object?>> sourceItems,
    List<CatalogDiagnostic> diagnostics,
  ) {
    final items = _items(documents, 'reward_rules.json');
    final rewardRuleIds = idsByFile['reward_rules.json']!;

    for (var index = 0; index < items.length; index++) {
      final item = items[index];

      _checkReference(
        value: item['outputPointProgramId'],
        targetIds: idsByFile['point_programs.json']!,
        fileName: 'reward_rules.json',
        itemIndex: index,
        fieldName: 'outputPointProgramId',
        diagnostics: diagnostics,
      );

      _checkSelectorReferences(
        item['selectors'],
        idsByFile,
        index,
        'selectors',
        diagnostics,
      );
      _checkSelectorReferences(
        item['exclusions'],
        idsByFile,
        index,
        'exclusions',
        diagnostics,
      );

      _checkConditionExpression(
        item['conditionExpression'],
        idsByFile['condition_definitions.json']!,
        index,
        diagnostics,
      );

      final calculation = item['calculation'];
      if (calculation is Map && calculation['calculationType'] == 'mirror') {
        final sourceRuleId = calculation['sourceRuleId'];

        if (sourceRuleId is String && !rewardRuleIds.contains(sourceRuleId)) {
          diagnostics.add(
            _diagnostic(
              'CAT-E006',
              'The mirror source reward rule does not exist.',
              path: 'reward_rules.json/items/$index/calculation/sourceRuleId',
              context: <String, Object?>{
                'referencedId': sourceRuleId,
              },
            ),
          );
        }
      }

      final stacking = item['stacking'];
      if (stacking is Map) {
        for (final fieldName in <String>[
          'replacesRuleIds',
          'suppressesRuleIds',
          'dependsOnRuleIds',
        ]) {
          _checkListReferences(
            value: stacking[fieldName],
            targetIds: rewardRuleIds,
            fileName: 'reward_rules.json',
            itemIndex: index,
            fieldName: 'stacking/$fieldName',
            diagnostics: diagnostics,
          );
        }
      }

      if (item['status'] == 'active') {
        final sourceIds = item['sourceIds'];
        final hasPrimarySource = sourceIds is List &&
            sourceIds.whereType<String>().any(
                  (id) => sourceItems[id]?['reliability'] == 'primary',
                );

        if (!hasPrimarySource) {
          diagnostics.add(
            _diagnostic(
              'CAT-E008',
              'An active reward rule requires a primary source.',
              path: 'reward_rules.json/items/$index/sourceIds',
            ),
          );
        }
      }
    }
  }

  void _validateValidityPeriods(
    Map<String, Object?> documents,
    List<CatalogDiagnostic> diagnostics,
  ) {
    for (final fileName in _catalogFiles) {
      final items = _items(documents, fileName);

      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final validFrom = _tryParseCatalogDate(item['validFrom']);
        final validUntilExclusive = _tryParseCatalogDate(
          item['validUntilExclusive'],
        );

        // Invalid date representations are handled by JSON Schema validation.
        if (validFrom == null || validUntilExclusive == null) {
          continue;
        }

        final startsAfterEnd = validFrom.isAfter(validUntilExclusive);
        final activeEmptyInterval = item['status'] == 'active' &&
            validFrom.isAtSameMomentAs(validUntilExclusive);

        if (!startsAfterEnd && !activeEmptyInterval) {
          continue;
        }

        diagnostics.add(
          _diagnostic(
            'CAT-E002',
            startsAfterEnd
                ? 'The validity period starts after it ends.'
                : 'An active item must have a non-empty validity period.',
            path: '$fileName/items/$index/validUntilExclusive',
            context: <String, Object?>{
              'validFrom': item['validFrom'],
              'validUntilExclusive': item['validUntilExclusive'],
              'reason':
                  startsAfterEnd ? 'startAfterEnd' : 'activeEmptyInterval',
            },
          ),
        );
      }
    }
  }

  DateTime? _tryParseCatalogDate(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }

    final parts = value.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final parsed = DateTime.utc(year, month, day);

    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }

    return parsed;
  }

  void _validateConditionExpressionLimits(
    Map<String, Object?> documents,
    List<CatalogDiagnostic> diagnostics,
  ) {
    final items = _items(documents, 'reward_rules.json');

    for (var index = 0; index < items.length; index++) {
      final expression = items[index]['conditionExpression'];
      if (expression is! Map) {
        continue;
      }

      final statistics = _conditionExpressionStatistics(expression);
      final nodeCount = statistics[0];
      final maximumDepth = statistics[1];

      if (nodeCount <= _maximumConditionNodeCount &&
          maximumDepth <= _maximumConditionDepth) {
        continue;
      }

      diagnostics.add(
        _diagnostic(
          'CAT-E013',
          'ConditionExpression exceeds the supported complexity limits.',
          path: 'reward_rules.json/items/$index/conditionExpression',
          context: <String, Object?>{
            'nodeCount': nodeCount,
            'maximumAllowedNodeCount': _maximumConditionNodeCount,
            'maximumDepth': maximumDepth,
            'maximumAllowedDepth': _maximumConditionDepth,
          },
        ),
      );
    }
  }

  List<int> _conditionExpressionStatistics(
    Map<dynamic, dynamic> root,
  ) {
    final pending = <MapEntry<Object?, int>>[
      MapEntry<Object?, int>(root, 1),
    ];

    var nodeCount = 0;
    var maximumDepth = 0;

    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      final node = current.key;

      if (node is! Map) {
        continue;
      }

      nodeCount++;
      if (current.value > maximumDepth) {
        maximumDepth = current.value;
      }

      final children = node['children'];
      if (children is List) {
        for (final child in children.reversed) {
          pending.add(
            MapEntry<Object?, int>(
              child,
              current.value + 1,
            ),
          );
        }
      }

      if (node.containsKey('child')) {
        pending.add(
          MapEntry<Object?, int>(
            node['child'],
            current.value + 1,
          ),
        );
      }
    }

    return <int>[nodeCount, maximumDepth];
  }

  void _validateRewardRuleMirrorCycles(
    Map<String, Object?> documents,
    List<CatalogDiagnostic> diagnostics,
  ) {
    final items = _items(documents, 'reward_rules.json');
    final ruleIds = items.map((item) => item['id']).whereType<String>().toSet();

    final graph = <String, Set<String>>{
      for (final id in ruleIds) id: <String>{},
    };

    for (final item in items) {
      final id = item['id'];
      final calculation = item['calculation'];

      if (id is! String || calculation is! Map) {
        continue;
      }

      if (calculation['calculationType'] != 'mirror') {
        continue;
      }

      final sourceRuleId = calculation['sourceRuleId'];

      if (sourceRuleId is String && ruleIds.contains(sourceRuleId)) {
        graph[id]!.add(sourceRuleId);
      }
    }

    final cycle = _findCycle(graph);
    if (cycle != null) {
      diagnostics.add(
        _diagnostic(
          'CAT-E007',
          'RewardRule mirror references contain a cycle.',
          path: 'reward_rules.json',
          context: <String, Object?>{
            'cycle': cycle,
          },
        ),
      );
    }
  }

  void _validateMerchantCategoryCycles(
    Map<String, Object?> documents,
    List<CatalogDiagnostic> diagnostics,
  ) {
    final items = _items(
      documents,
      'merchant_categories.json',
    );

    final categoryIds =
        items.map((item) => item['id']).whereType<String>().toSet();

    final graph = <String, Set<String>>{
      for (final id in categoryIds) id: <String>{},
    };

    for (final item in items) {
      final id = item['id'];
      final parentId = item['parentCategoryId'];

      if (id is String &&
          parentId is String &&
          categoryIds.contains(parentId)) {
        graph[id]!.add(parentId);
      }
    }

    final cycle = _findCycle(graph);
    if (cycle != null) {
      diagnostics.add(
        _diagnostic(
          'CAT-F006',
          'MerchantCategory parent references contain a cycle.',
          path: 'merchant_categories.json',
          context: <String, Object?>{
            'cycle': cycle,
            'cycleType': 'merchantCategoryParent',
          },
        ),
      );
    }
  }

  void _validateIdMigrationCycles(
    Map<String, Object?> documents,
    List<CatalogDiagnostic> diagnostics,
  ) {
    final items = _items(documents, 'id_migrations.json');
    final graphsByEntityType = <String, Map<String, Set<String>>>{};

    for (final item in items) {
      final entityType = item['entityType'];
      final fromIds = item['fromIds'];
      final toIds = item['toIds'];

      if (entityType is! String || fromIds is! List || toIds is! List) {
        continue;
      }

      final graph = graphsByEntityType.putIfAbsent(
        entityType,
        () => <String, Set<String>>{},
      );

      final sources = fromIds.whereType<String>();
      final destinations = toIds.whereType<String>();

      for (final source in sources) {
        final edges = graph.putIfAbsent(
          source,
          () => <String>{},
        );

        for (final destination in destinations) {
          edges.add(destination);
          graph.putIfAbsent(
            destination,
            () => <String>{},
          );
        }
      }
    }

    for (final entry in graphsByEntityType.entries) {
      final cycle = _findCycle(entry.value);

      if (cycle == null) {
        continue;
      }

      diagnostics.add(
        _diagnostic(
          'CAT-F006',
          'ID migration references contain a cycle.',
          path: 'id_migrations.json',
          context: <String, Object?>{
            'cycle': cycle,
            'cycleType': 'idMigration',
            'entityType': entry.key,
          },
        ),
      );
    }
  }

  List<String>? _findCycle(
    Map<String, Set<String>> graph,
  ) {
    final states = <String, int>{};

    for (final start in graph.keys) {
      if ((states[start] ?? 0) != 0) {
        continue;
      }

      final nodeStack = <String>[start];
      final edgeStack = <Iterator<String>>[
        (graph[start] ?? const <String>{}).iterator,
      ];
      final stackIndexes = <String, int>{
        start: 0,
      };

      states[start] = 1;

      while (nodeStack.isNotEmpty) {
        final edges = edgeStack.last;

        if (edges.moveNext()) {
          final next = edges.current;
          final state = states[next] ?? 0;

          if (state == 0) {
            states[next] = 1;
            stackIndexes[next] = nodeStack.length;
            nodeStack.add(next);
            edgeStack.add(
              (graph[next] ?? const <String>{}).iterator,
            );
            continue;
          }

          if (state == 1) {
            final cycleStartIndex = stackIndexes[next]!;
            return List<String>.unmodifiable(
              <String>[
                ...nodeStack.sublist(cycleStartIndex),
                next,
              ],
            );
          }

          continue;
        }

        final completed = nodeStack.removeLast();
        edgeStack.removeLast();
        stackIndexes.remove(completed);
        states[completed] = 2;
      }
    }

    return null;
  }

  void _checkSelectorReferences(
    Object? selectorValue,
    Map<String, Set<String>> idsByFile,
    int itemIndex,
    String selectorName,
    List<CatalogDiagnostic> diagnostics,
  ) {
    if (selectorValue is! Map) {
      return;
    }

    const targets = <String, String>{
      'instrumentIds': 'payment_instruments.json',
      'modeIds': 'payment_modes.json',
      'routeIds': 'payment_routes.json',
      'fundingRelationIds': 'funding_relations.json',
      'merchantIds': 'merchants.json',
      'merchantGroupIds': 'merchant_groups.json',
      'categoryIds': 'merchant_categories.json',
    };

    for (final entry in targets.entries) {
      _checkListReferences(
        value: selectorValue[entry.key],
        targetIds: idsByFile[entry.value]!,
        fileName: 'reward_rules.json',
        itemIndex: itemIndex,
        fieldName: '$selectorName/${entry.key}',
        diagnostics: diagnostics,
      );
    }
  }

  void _checkConditionExpression(
    Object? value,
    Set<String> conditionIds,
    int itemIndex,
    List<CatalogDiagnostic> diagnostics, [
    String path = 'conditionExpression',
  ]) {
    final pending = <MapEntry<Object?, String>>[
      MapEntry<Object?, String>(value, path),
    ];

    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      final node = current.key;

      if (node is! Map) {
        continue;
      }

      final conditionId = node['conditionId'];
      if (conditionId is String && !conditionIds.contains(conditionId)) {
        diagnostics.add(
          _diagnostic(
            'CAT-E001',
            'A referenced catalog item does not exist.',
            path:
                'reward_rules.json/items/$itemIndex/${current.value}/conditionId',
            context: <String, Object?>{
              'referencedId': conditionId,
            },
          ),
        );
      }

      // Push the single child first because this is a LIFO stack.
      // This preserves the previous traversal order: children, then child.
      if (node.containsKey('child')) {
        pending.add(
          MapEntry<Object?, String>(
            node['child'],
            '${current.value}/child',
          ),
        );
      }

      final children = node['children'];
      if (children is List) {
        for (var index = children.length - 1; index >= 0; index--) {
          pending.add(
            MapEntry<Object?, String>(
              children[index],
              '${current.value}/children/$index',
            ),
          );
        }
      }
    }
  }

  void _checkReference({
    required Object? value,
    required Set<String> targetIds,
    required String fileName,
    required int itemIndex,
    required String fieldName,
    required List<CatalogDiagnostic> diagnostics,
  }) {
    if (value is String && !targetIds.contains(value)) {
      diagnostics.add(
        _diagnostic(
          'CAT-E001',
          'A referenced catalog item does not exist.',
          path: '$fileName/items/$itemIndex/$fieldName',
          context: <String, Object?>{
            'referencedId': value,
          },
        ),
      );
    }
  }

  void _checkListReferences({
    required Object? value,
    required Set<String> targetIds,
    required String fileName,
    required int itemIndex,
    required String fieldName,
    required List<CatalogDiagnostic> diagnostics,
  }) {
    if (value is! List) {
      return;
    }

    for (var index = 0; index < value.length; index++) {
      final reference = value[index];

      if (reference is String && !targetIds.contains(reference)) {
        diagnostics.add(
          _diagnostic(
            'CAT-E001',
            'A referenced catalog item does not exist.',
            path: '$fileName/items/$itemIndex/$fieldName/$index',
            context: <String, Object?>{
              'referencedId': reference,
            },
          ),
        );
      }
    }
  }

  List<Map<String, Object?>> _items(
    Map<String, Object?> documents,
    String fileName,
  ) {
    final document = documents[fileName];
    if (document is! Map) {
      return const <Map<String, Object?>>[];
    }

    final values = document['items'];
    if (values is! List) {
      return const <Map<String, Object?>>[];
    }

    return values
        .whereType<Map>()
        .map(Map<String, Object?>.from)
        .toList(growable: false);
  }

  CatalogDiagnostic _diagnostic(
    String code,
    String message, {
    String? path,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    return CatalogDiagnostic(
      code: CatalogDiagnosticCode.parse(code),
      message: message,
      path: path,
      context: context,
    );
  }

  static const int _maximumConditionDepth = 10;
  static const int _maximumConditionNodeCount = 100;

  static const List<String> _catalogFiles = <String>[
    'payment_instruments.json',
    'payment_routes.json',
    'payment_modes.json',
    'funding_relations.json',
    'merchant_groups.json',
    'merchants.json',
    'merchant_categories.json',
    'point_programs.json',
    'condition_definitions.json',
    'reward_rules.json',
    'sources.json',
    'id_migrations.json',
  ];
}

import 'dart:convert';

import 'package:bestpay/application/settings/condition_options_repository.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/settings/condition_option.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 同梱の `assets/data/condition_definitions.json` から条件定義を読む。
///
/// 読めない場合は空を返し、条件なしで動かす（起動を止めない）。
final class AssetConditionOptionsRepository
    implements ConditionOptionsRepository {
  const AssetConditionOptionsRepository();

  static const String _path = 'assets/data/condition_definitions.json';

  @override
  Future<List<ConditionOption>> load() async {
    try {
      final decoded = json.decode(await rootBundle.loadString(_path));
      final raw = (decoded as Map<dynamic, dynamic>)['items'];

      if (raw is! List) {
        return const <ConditionOption>[];
      }

      final options = <ConditionOption>[];
      for (final item in raw) {
        if (item is! Map) {
          continue;
        }

        final map = item.cast<String, Object?>();
        final id = map['id'];
        final name = map['name'];
        if (id is! String || id.isEmpty || name is! String) {
          continue;
        }

        options.add(
          ConditionOption(
            id: id,
            name: name,
            description: map['description'] is String
                ? map['description']! as String
                : '',
            defaultState: _stateOf(map['defaultState']),
            notes: <String>[
              for (final note in (map['notes'] is List
                  ? map['notes']! as List
                  : const <Object?>[]))
                if (note is String) note,
            ],
            ownerInstrumentIds: <String>[
              for (final owner in (map['ownerInstrumentIds'] is List
                  ? map['ownerInstrumentIds']! as List
                  : const <Object?>[]))
                if (owner is String) owner,
            ],
            valueType: map['valueType'] == 'integer' ? 'integer' : 'boolean',
            minimumCount: _intOf(map['minimumCount']),
            maximumCount: _intOf(map['maximumCount']),
            countGroupId: map['countGroupId'] is String
                ? map['countGroupId']! as String
                : null,
            countGroupMax: _intOf(map['countGroupMax']),
          ),
        );
      }

      return List<ConditionOption>.unmodifiable(options);
    } on Object {
      return const <ConditionOption>[];
    }
  }

  static int _intOf(Object? raw) {
    if (raw is int) {
      return raw;
    }

    return 0;
  }

  static TriState _stateOf(Object? raw) {
    for (final state in TriState.values) {
      if (state.name == raw) {
        return state;
      }
    }

    return TriState.unknown;
  }
}

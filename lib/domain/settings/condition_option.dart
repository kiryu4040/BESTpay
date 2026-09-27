import 'package:bestpay/core/value_objects/tri_state.dart';

/// 還元率の基準になる条件1件（D-101）。
///
/// カタログには定義だけを置き、達成状態は利用者が決めて端末に保存する。
final class ConditionOption {
  const ConditionOption({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultState,
    required this.notes,
  });

  final String id;
  final String name;
  final String description;

  /// 利用者が何も決めていないときに使う状態。
  final TriState defaultState;

  final List<String> notes;
}

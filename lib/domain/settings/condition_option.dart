import 'package:bestpay/core/value_objects/tri_state.dart';

/// 還元率の基準になる条件1件（D-101・D-114・D-119）。
///
/// カタログには定義だけを置き、達成状態は利用者が決めて端末に保存する。
final class ConditionOption {
  const ConditionOption({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultState,
    required this.notes,
    this.ownerInstrumentIds = const <String>[],
    this.valueType = 'boolean',
    this.maximumCount = 0,
    this.minimumCount = 0,
    this.countGroupId,
    this.countGroupMax = 0,
  });

  final String id;
  final String name;
  final String description;

  /// 利用者が何も決めていないときに使う状態。
  final TriState defaultState;

  final List<String> notes;

  /// この条件が効くカードのID（設定画面のカード別の分類に使う）。
  final List<String> ownerInstrumentIds;

  /// `boolean` なら入切、`integer` なら個数。
  final String valueType;

  final int minimumCount;
  final int maximumCount;

  /// 同じまとまりとして1項目で出す条件のID（D-119）。null なら単独。
  final String? countGroupId;

  /// まとまり全体の最大数。
  final int countGroupMax;

  /// 個数を選ぶ条件か。
  bool get isCount => valueType == 'integer';
}

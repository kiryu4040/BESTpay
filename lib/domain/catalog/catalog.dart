import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/catalog/models/catalog_entity.dart';
import 'package:bestpay/domain/catalog/models/payment_instrument_models.dart';
import 'package:bestpay/domain/catalog/models/point_program_models.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:bestpay/domain/catalog/models/source_models.dart';

/// An immutable, typed view of the catalog documents loaded at startup.
///
/// The catalog is allowed to be empty: "no cards registered yet" is the
/// normal initial state, and every accessor is safe on an empty catalog.
final class Catalog {
  Catalog({
    this.catalogVersion,
    this.generatedAt,
    required Iterable<PaymentInstrument> paymentInstruments,
    required Iterable<PointProgram> pointPrograms,
    required Iterable<RewardRule> rewardRules,
    required Iterable<CatalogSource> sources,
  })  : paymentInstrumentsById = _index(
          paymentInstruments,
          'paymentInstruments',
        ),
        pointProgramsById = _index(pointPrograms, 'pointPrograms'),
        rewardRulesById = _index(rewardRules, 'rewardRules'),
        sourcesById = _index(sources, 'sources');

  /// The empty catalog used when the bundled data is missing or unusable.
  factory Catalog.empty() {
    return Catalog(
      paymentInstruments: const <PaymentInstrument>[],
      pointPrograms: const <PointProgram>[],
      rewardRules: const <RewardRule>[],
      sources: const <CatalogSource>[],
    );
  }

  /// Raw catalog version string (`YYYY.MM.DD.REVISION`) when present.
  final String? catalogVersion;

  /// Raw generation timestamp when present.
  final String? generatedAt;

  final Map<StableId, PaymentInstrument> paymentInstrumentsById;
  final Map<StableId, PointProgram> pointProgramsById;
  final Map<StableId, RewardRule> rewardRulesById;
  final Map<StableId, CatalogSource> sourcesById;

  bool get isEmpty => paymentInstrumentsById.isEmpty;

  bool get isNotEmpty => paymentInstrumentsById.isNotEmpty;

  /// Reward rules that could apply to [instrumentId] during normal usage.
  ///
  /// A rule with an empty instrument selector applies to every instrument.
  /// The result is ordered by identifier so evaluation is deterministic.
  List<RewardRule> rulesApplicableToInstrument(StableId instrumentId) {
    final rules = <RewardRule>[
      for (final rule in rewardRulesById.values)
        if (rule.selectors.instrumentIds.isEmpty ||
            rule.selectors.instrumentIds.contains(instrumentId))
          rule,
    ]..sort((left, right) => left.id.value.compareTo(right.id.value));

    return List<RewardRule>.unmodifiable(rules);
  }
}

Map<StableId, T> _index<T extends CatalogEntity>(
  Iterable<T> entities,
  String fieldName,
) {
  final index = <StableId, T>{};

  for (final entity in entities) {
    if (index.containsKey(entity.id)) {
      throw ArgumentError.value(
        entity.id,
        fieldName,
        'Duplicate catalog ID.',
      );
    }

    index[entity.id] = entity;
  }

  return Map<StableId, T>.unmodifiable(index);
}

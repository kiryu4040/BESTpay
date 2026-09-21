import '../../../core/value_objects/stable_id.dart';
import 'catalog_entity.dart';
import 'condition_models.dart';
import 'instrument_models.dart';
import 'merchant_models.dart';
import 'point_program_models.dart';
import 'reward_rule_models.dart';
import 'source_migration_models.dart';

/// An immutable, fully typed view of all validated catalog documents.
///
/// Construction is atomic: duplicate IDs in any individual catalog cause the
/// constructor to fail instead of exposing a partial typed catalog.
final class TypedCatalog {
  TypedCatalog({
    required Iterable<PaymentInstrument> paymentInstruments,
    required Iterable<PaymentRoute> paymentRoutes,
    required Iterable<PaymentMode> paymentModes,
    required Iterable<FundingRelation> fundingRelations,
    required Iterable<Merchant> merchants,
    required Iterable<MerchantGroup> merchantGroups,
    required Iterable<MerchantCategory> merchantCategories,
    required Iterable<PointProgram> pointPrograms,
    required Iterable<ConditionDefinition> conditionDefinitions,
    required Iterable<RewardRule> rewardRules,
    required Iterable<CatalogSource> sources,
    required Iterable<IdMigration> idMigrations,
  })  : paymentInstruments = _indexById(
          paymentInstruments,
          'paymentInstruments',
        ),
        paymentRoutes = _indexById(paymentRoutes, 'paymentRoutes'),
        paymentModes = _indexById(paymentModes, 'paymentModes'),
        fundingRelations = _indexById(
          fundingRelations,
          'fundingRelations',
        ),
        merchants = _indexById(merchants, 'merchants'),
        merchantGroups = _indexById(merchantGroups, 'merchantGroups'),
        merchantCategories = _indexById(
          merchantCategories,
          'merchantCategories',
        ),
        pointPrograms = _indexById(pointPrograms, 'pointPrograms'),
        conditionDefinitions = _indexById(
          conditionDefinitions,
          'conditionDefinitions',
        ),
        rewardRules = _indexById(rewardRules, 'rewardRules'),
        sources = _indexById(sources, 'sources'),
        idMigrations = _indexById(idMigrations, 'idMigrations');

  final Map<StableId, PaymentInstrument> paymentInstruments;
  final Map<StableId, PaymentRoute> paymentRoutes;
  final Map<StableId, PaymentMode> paymentModes;
  final Map<StableId, FundingRelation> fundingRelations;
  final Map<StableId, Merchant> merchants;
  final Map<StableId, MerchantGroup> merchantGroups;
  final Map<StableId, MerchantCategory> merchantCategories;
  final Map<StableId, PointProgram> pointPrograms;
  final Map<StableId, ConditionDefinition> conditionDefinitions;
  final Map<StableId, RewardRule> rewardRules;
  final Map<StableId, CatalogSource> sources;
  final Map<StableId, IdMigration> idMigrations;
}

Map<StableId, T> _indexById<T extends CatalogEntity>(
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

import 'package:bestpay/application/catalog/catalog_repository.dart';
import 'package:bestpay/application/merchant/merchant_directory_repository.dart';
import 'package:bestpay/application/ranking/reward_ranking_usecase.dart';
import 'package:bestpay/core/time/clock.dart';
import 'package:bestpay/core/time/system_clock.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/infrastructure/merchant/asset_merchant_directory_repository.dart';
import 'package:bestpay/domain/ranking/reward_ranking.dart';
import 'package:flutter/foundation.dart';

/// Holds the loaded catalog and the latest ranking for the UI.
///
/// This type performs no calculation itself: it delegates loading to the
/// [CatalogRepository] contract and ranking to [RewardRankingUseCase], so no
/// reward math lives in the presentation layer (D-60).
final class RankingController extends ChangeNotifier {
  RankingController({
    required CatalogRepository repository,
    MerchantDirectoryRepository directoryRepository =
        const AssetMerchantDirectoryRepository(),
    RewardRankingUseCase useCase = const RewardRankingUseCase(),
    Clock clock = const SystemClock(),
  })  : _repository = repository,
        _directoryRepository = directoryRepository,
        _useCase = useCase,
        _clock = clock;

  final CatalogRepository _repository;
  final MerchantDirectoryRepository _directoryRepository;
  final RewardRankingUseCase _useCase;
  final Clock _clock;

  /// 利用者本人が確認済みの条件（D-084）。
  ///
  /// みずほ楽天カードのWポイントプランは本人が対象者であることを確認済み
  /// なので、既定で充足として扱い、基準を2%にする。条件設定画面から
  /// 変更できるようにするのは第2期。
  ConditionEvaluationContext get _defaultConditionContext =>
      ConditionEvaluationContext(
        states: <StableId, TriState>{
          StableId.create('mizuho_w_point_plan_eligible').fold(
            onSuccess: (value) => value,
            onFailure: (_) => throw StateError('invalid condition id'),
          ): TriState.satisfied,
        },
      );

  Catalog _catalog = Catalog.empty();
  MerchantDirectory _directory = MerchantDirectory.empty();
  MerchantEntry? _selectedMerchant;
  RewardRanking? _ranking;
  bool _isLoading = false;

  Catalog get catalog => _catalog;

  RewardRanking? get ranking => _ranking;

  bool get isLoading => _isLoading;

  bool get isCatalogEmpty => _catalog.isEmpty;

  /// レジ前で選ぶ店舗の一覧。
  MerchantDirectory get directory => _directory;

  bool get isDirectoryEmpty => _directory.isEmpty;

  /// いま比較している店舗。
  MerchantEntry? get selectedMerchant => _selectedMerchant;

  /// Loads (or reloads) the catalog. Never throws.
  Future<void> loadCatalog() async {
    _isLoading = true;
    notifyListeners();

    _catalog = await _repository.load();
    _directory = await _directoryRepository.load();

    _isLoading = false;
    notifyListeners();
  }

  /// Discards the previous result so the screen can return to its initial
  /// state (D-12, D-47).
  void clearRanking() {
    _ranking = null;
    _selectedMerchant = null;
    notifyListeners();
  }

  /// 店舗を選んだだけで比較する（D-088）。
  ///
  /// 金額は入力させない。比較は還元率で行うため、内部の基準額
  /// （1万円）でカードごとの還元率を求める（D-090）。
  void compareAtMerchant(MerchantEntry merchant) {
    _selectedMerchant = merchant;
    _ranking = _useCase.execute(
      catalog: _catalog,
      amount: RewardRankingUseCase.comparisonAmount,
      transactionDate: currentJstDate(),
      conditionContext: _defaultConditionContext,
      merchantId: merchant.id,
      merchantGroupIds: merchant.groupIds,
      categoryIds: merchant.categoryIds,
    );
    notifyListeners();
  }

  /// 金額を指定して比較する。年間タブ用に残している（店舗タブでは使わない）。
  void showRankingFor({required MoneyYen amount}) {
    _ranking = _useCase.execute(
      catalog: _catalog,
      amount: amount,
      transactionDate: currentJstDate(),
      conditionContext: _defaultConditionContext,
    );
    notifyListeners();
  }

  /// The current instant shifted to Japan Standard Time (UTC+9).
  DateTime get currentJstInstant =>
      _clock.nowUtc().add(const Duration(hours: 9));

  /// The current JST calendar date used as the default transaction date.
  CalculationDate currentJstDate() {
    final instant = currentJstInstant;

    return CalculationDate.create(
      instant.year,
      instant.month,
      instant.day,
    ).fold(
      onSuccess: (date) => date,
      onFailure: (_) => throw StateError('The current JST date is invalid.'),
    );
  }

  /// Compact label for the current JST date, for example `2026-09-27`.
  String get currentDateLabel {
    final instant = currentJstInstant;
    String two(int value) => value.toString().padLeft(2, '0');

    return '${instant.year}-${two(instant.month)}-${two(instant.day)}';
  }
}

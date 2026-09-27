import 'package:bestpay/application/catalog/catalog_repository.dart';
import 'package:bestpay/application/merchant/merchant_directory_repository.dart';
import 'package:bestpay/application/settings/category_order_store.dart';
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
import 'package:bestpay/infrastructure/settings/shared_preferences_category_order_store.dart';
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
    CategoryOrderStore categoryOrderStore =
        const SharedPreferencesCategoryOrderStore(),
    RewardRankingUseCase useCase = const RewardRankingUseCase(),
    Clock clock = const SystemClock(),
  })  : _repository = repository,
        _directoryRepository = directoryRepository,
        _categoryOrderStore = categoryOrderStore,
        _useCase = useCase,
        _clock = clock;

  final CatalogRepository _repository;
  final MerchantDirectoryRepository _directoryRepository;
  final CategoryOrderStore _categoryOrderStore;
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
  final Map<String, int> _bestRateCache = <String, int>{};
  List<String> _categoryOrder = const <String>[];
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

  /// カタログが空のときに、読み込めなかったファイル名を返す（原因究明用）。
  List<String> get missingCatalogFiles {
    final repository = _repository;
    if (repository is CatalogDiagnosticsSource) {
      return (repository as CatalogDiagnosticsSource).missingFileNames;
    }

    return const <String>[];
  }

  /// いま比較している店舗。
  MerchantEntry? get selectedMerchant => _selectedMerchant;

  /// 保存された並び順を反映したカテゴリ一覧（D-095）。
  ///
  /// 保存順に無いカテゴリは元の順のまま後ろに並ぶ。新しいカテゴリが
  /// 増えても消えずに表示される。
  List<MerchantCategory> get orderedCategories {
    final base = _directory.orderedCategories;
    if (_categoryOrder.isEmpty) {
      return base;
    }

    final rank = <String, int>{
      for (var index = 0; index < _categoryOrder.length; index++)
        _categoryOrder[index]: index,
    };

    final ordered = base.toList()
      ..sort((left, right) {
        final leftRank = rank[left.id.value] ?? _categoryOrder.length;
        final rightRank = rank[right.id.value] ?? _categoryOrder.length;
        if (leftRank != rightRank) {
          return leftRank - rightRank;
        }

        return base.indexOf(left) - base.indexOf(right);
      });

    return List<MerchantCategory>.unmodifiable(ordered);
  }

  /// カテゴリの並び順を保存して画面に反映する。
  Future<void> saveCategoryOrder(List<MerchantCategory> categories) async {
    _categoryOrder = <String>[
      for (final category in categories) category.id.value,
    ];
    notifyListeners();

    await _categoryOrderStore.save(_categoryOrder);
  }

  /// Loads (or reloads) the catalog. Never throws.
  Future<void> loadCatalog() async {
    _isLoading = true;
    notifyListeners();

    _catalog = await _repository.load();
    _directory = await _directoryRepository.load();
    _categoryOrder = await _categoryOrderStore.load();

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

  /// その店舗で最も高い還元率（100分の1%単位。8.00%なら800）。
  ///
  /// 並べ替えに使う。同じ店舗を何度も評価しないよう結果を覚えておく。
  int bestRateHundredthsPercentAt(MerchantEntry merchant) {
    final key = merchant.id.value;
    final cached = _bestRateCache[key];
    if (cached != null) {
      return cached;
    }

    final ranking = _useCase.execute(
      catalog: _catalog,
      amount: RewardRankingUseCase.comparisonAmount,
      transactionDate: currentJstDate(),
      conditionContext: _defaultConditionContext,
      merchantId: merchant.id,
      merchantGroupIds: merchant.groupIds,
      categoryIds: merchant.categoryIds,
    );

    final best = ranking.bestEntry;
    final value = best == null
        ? BigInt.zero
        : (BigInt.from(best.effectiveRate.numerator) * BigInt.from(10000)) ~/
            BigInt.from(best.effectiveRate.denominator);

    final result = value.toInt();
    _bestRateCache[key] = result;

    return result;
  }

  /// 並べ替え表示用のラベル（例: `8.00%`）。
  String bestRateLabelAt(MerchantEntry merchant) {
    final hundredths = bestRateHundredthsPercentAt(merchant);
    final whole = hundredths ~/ 100;
    final fraction = (hundredths % 100).toString().padLeft(2, '0');

    return '$whole.$fraction%';
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

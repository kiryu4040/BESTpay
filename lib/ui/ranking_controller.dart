import 'package:bestpay/application/annual/annual_record_store.dart';
import 'package:bestpay/application/annual/annual_record_summary.dart';
import 'package:bestpay/application/catalog/catalog_repository.dart';
import 'package:bestpay/application/merchant/merchant_directory_repository.dart';
import 'package:bestpay/application/ranking/annual_reward_summary_usecase.dart';
import 'package:bestpay/application/ranking/reward_ranking_usecase.dart';
import 'package:bestpay/application/settings/condition_options_repository.dart';
import 'package:bestpay/application/settings/user_preferences.dart';
import 'package:bestpay/application/settings/user_preferences_store.dart';
import 'package:bestpay/core/time/clock.dart';
import 'package:bestpay/core/time/system_clock.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/annual/annual_record.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/catalog/models/payment_instrument_models.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/domain/ranking/reward_ranking.dart';
import 'package:bestpay/domain/settings/condition_option.dart';
import 'package:bestpay/infrastructure/annual/shared_preferences_annual_record_store.dart';
import 'package:bestpay/infrastructure/merchant/asset_merchant_directory_repository.dart';
import 'package:bestpay/infrastructure/settings/asset_condition_options_repository.dart';
import 'package:bestpay/infrastructure/settings/shared_preferences_user_preferences_store.dart';
import 'package:flutter/foundation.dart';

/// カタログ・店舗一覧・利用者設定を保持し、比較結果を組み立てる（D-60）。
///
/// 計算そのものは domain 層に任せ、この型は状態の保持と並べ替えだけを行う。
final class RankingController extends ChangeNotifier {
  RankingController({
    required CatalogRepository repository,
    MerchantDirectoryRepository directoryRepository =
        const AssetMerchantDirectoryRepository(),
    ConditionOptionsRepository conditionOptionsRepository =
        const AssetConditionOptionsRepository(),
    UserPreferencesStore preferencesStore =
        const SharedPreferencesUserPreferencesStore(),
    AnnualRecordStore recordStore =
        const SharedPreferencesAnnualRecordStore(),
    AnnualRecordSummaryUseCase recordSummaryUseCase =
        const AnnualRecordSummaryUseCase(),
    RewardRankingUseCase useCase = const RewardRankingUseCase(),
    AnnualRewardSummaryUseCase annualUseCase =
        const AnnualRewardSummaryUseCase(),
    Clock clock = const SystemClock(),
  })  : _repository = repository,
        _directoryRepository = directoryRepository,
        _conditionOptionsRepository = conditionOptionsRepository,
        _preferencesStore = preferencesStore,
        _recordStore = recordStore,
        _recordSummaryUseCase = recordSummaryUseCase,
        _useCase = useCase,
        _annualUseCase = annualUseCase,
        _clock = clock;

  final CatalogRepository _repository;
  final MerchantDirectoryRepository _directoryRepository;
  final ConditionOptionsRepository _conditionOptionsRepository;
  final UserPreferencesStore _preferencesStore;
  final AnnualRecordStore _recordStore;
  final AnnualRecordSummaryUseCase _recordSummaryUseCase;
  final RewardRankingUseCase _useCase;
  final AnnualRewardSummaryUseCase _annualUseCase;
  final Clock _clock;

  Catalog _catalog = Catalog.empty();
  MerchantDirectory _directory = MerchantDirectory.empty();
  List<ConditionOption> _conditionOptions = const <ConditionOption>[];
  UserPreferences _preferences = const UserPreferences();
  MerchantEntry? _selectedMerchant;
  RewardRanking? _ranking;
  AnnualRewardSummary? _annualSummary;
  bool _isLoading = false;
  List<AnnualRecord> _records = const <AnnualRecord>[];
  AnnualRecordSummary? _recordSummary;
  final Map<String, int> _bestRateCache = <String, int>{};

  Catalog get catalog => _catalog;

  RewardRanking? get ranking => _ranking;

  AnnualRewardSummary? get annualSummary => _annualSummary;

  bool get isLoading => _isLoading;

  bool get isCatalogEmpty => _catalog.isEmpty;

  MerchantDirectory get directory => _directory;

  bool get isDirectoryEmpty => _directory.isEmpty;

  MerchantEntry? get selectedMerchant => _selectedMerchant;

  List<ConditionOption> get conditionOptions => _conditionOptions;

  UserPreferences get preferences => _preferences;

  /// 保存済みの並び順を反映したカテゴリ一覧（D-095）。
  List<MerchantCategory> get orderedCategories {
    final base = _directory.orderedCategories;
    final order = _preferences.categoryOrder;
    if (order.isEmpty) {
      return base;
    }

    final rank = <String, int>{
      for (var index = 0; index < order.length; index++) order[index]: index,
    };

    final ordered = base.toList()
      ..sort((left, right) {
        final leftRank = rank[left.id.value] ?? order.length;
        final rightRank = rank[right.id.value] ?? order.length;
        if (leftRank != rightRank) {
          return leftRank - rightRank;
        }

        return base.indexOf(left) - base.indexOf(right);
      });

    return List<MerchantCategory>.unmodifiable(ordered);
  }

  /// 保存済みの並び順を反映した、カテゴリ内の店舗一覧（D-099）。
  List<MerchantEntry> merchantsInCategoryOrdered(StableId categoryId) {
    final base = _directory.merchantsInCategory(categoryId);
    final order = _preferences.merchantOrder[categoryId.value];
    if (order == null || order.isEmpty) {
      return base;
    }

    final rank = <String, int>{
      for (var index = 0; index < order.length; index++) order[index]: index,
    };

    final ordered = base.toList()
      ..sort((left, right) {
        final leftRank = rank[left.id.value] ?? order.length;
        final rightRank = rank[right.id.value] ?? order.length;
        if (leftRank != rightRank) {
          return leftRank - rightRank;
        }

        return base.indexOf(left) - base.indexOf(right);
      });

    return List<MerchantEntry>.unmodifiable(ordered);
  }

  /// カタログが空のときに、読み込めなかったファイル名を返す（原因究明用）。
  List<String> get missingCatalogFiles {
    final repository = _repository;
    if (repository is CatalogDiagnosticsSource) {
      return (repository as CatalogDiagnosticsSource).missingFileNames;
    }

    return const <String>[];
  }

  /// 条件の現在の状態（保存値があればそれ、無ければカタログの既定）。
  TriState conditionStateOf(String conditionId) {
    final stored = _preferences.conditionStates[conditionId];
    if (stored != null) {
      return stored;
    }

    for (final option in _conditionOptions) {
      if (option.id == conditionId) {
        return option.defaultState;
      }
    }

    return TriState.unknown;
  }

  /// 条件の状態から作る評価用の文脈。不明な条件は入れない（D-50）。
  ConditionEvaluationContext get conditionContext {
    final states = <StableId, TriState>{};

    for (final option in _conditionOptions) {
      final state = conditionStateOf(option.id);
      if (state == TriState.unknown) {
        continue;
      }

      final id = StableId.create(option.id).fold(
        onSuccess: (value) => value,
        onFailure: (_) => null,
      );

      if (id != null) {
        states[id] = state;
      }
    }

    // 個数で選ぶ条件は値として渡す（D-119）。
    final values = <StableId, Object?>{};
    for (final option in _conditionOptions) {
      if (!option.isCount) {
        continue;
      }

      final id = StableId.create(option.id).fold(
        onSuccess: (value) => value,
        onFailure: (_) => null,
      );
      if (id != null) {
        values[id] = conditionCountOf(option.id);
      }
    }

    return ConditionEvaluationContext(states: states, values: values);
  }

  /// カードをランキングに出すか（D-082）。
  bool isCardVisible(String instrumentId) {
    return !_preferences.hiddenCardIds.contains(instrumentId);
  }

  /// カタログ・店舗一覧・条件定義・利用者設定をまとめて読み込む。例外は出さない。
  Future<void> loadCatalog() async {
    _isLoading = true;
    notifyListeners();

    _catalog = await _repository.load();
    _directory = await _directoryRepository.load();
    _conditionOptions = await _conditionOptionsRepository.load();
    _preferences = await _preferencesStore.load();
    _records = await _recordStore.load();
    _bestRateCache.clear();
    _recordSummary = null;

    _isLoading = false;
    notifyListeners();
  }

  /// ランキングを破棄して初期状態に戻す。
  void clearRanking() {
    _ranking = null;
    _selectedMerchant = null;
    notifyListeners();
  }

  /// その店舗で最も高い還元率（100分の1%単位。8.00%なら800）。
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
      conditionContext: conditionContext,
      merchantId: merchant.id,
      merchantGroupIds: merchant.groupIds,
      categoryIds: merchant.categoryIds,
    );

    final best = _applyVisibility(ranking).bestEntry;
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

  /// 店舗を選んだだけで比較する（D-088）。金額は入力させない。
  void compareAtMerchant(MerchantEntry merchant) {
    _selectedMerchant = merchant;
    _ranking = _applyVisibility(
      _useCase.execute(
        catalog: _catalog,
        amount: RewardRankingUseCase.comparisonAmount,
        transactionDate: currentJstDate(),
        conditionContext: conditionContext,
        merchantId: merchant.id,
        merchantGroupIds: merchant.groupIds,
        categoryIds: merchant.categoryIds,
      ),
    );
    notifyListeners();
  }

  /// 個数で選ぶ条件の数（未設定なら0）。
  int conditionCountOf(String conditionId) {
    final stored = _preferences.conditionCounts[conditionId];
    if (stored != null) {
      return stored;
    }

    return 0;
  }

  /// 個数で選ぶ条件の数を保存する（D-119）。
  Future<void> setConditionCount(String conditionId, int count) async {
    if (count < 0) {
      return;
    }

    final counts = Map<String, int>.from(_preferences.conditionCounts)
      ..[conditionId] = count;
    _bestRateCache.clear();
    _recordSummary = null;
    await _update(
      _preferences.copyWith(
        conditionCounts: counts,
        conditionStates: Map<String, TriState>.from(
          _preferences.conditionStates,
        )..[conditionId] =
            count > 0 ? TriState.satisfied : TriState.notSatisfied,
      ),
    );
  }

  /// 条件が効くカードの一覧（条件を1つ以上持つカードだけ）。
  List<PaymentInstrument> get instrumentsWithConditions {
    final instruments = _catalog.paymentInstrumentsById.values.toList()
      ..sort((left, right) => left.id.value.compareTo(right.id.value));

    return <PaymentInstrument>[
      for (final instrument in instruments)
        if (_conditionOptions.any(
          (option) => option.ownerInstrumentIds.contains(instrument.id.value),
        ))
          instrument,
    ];
  }

  /// そのカードに効く条件。
  List<ConditionOption> conditionsForInstrument(String instrumentId) {
    return <ConditionOption>[
      for (final option in _conditionOptions)
        if (option.ownerInstrumentIds.contains(instrumentId)) option,
    ];
  }

  /// カード1枚の条件の設定状況（例: `オン 3 件 / 全 9 件`）。
  String conditionSummaryFor(String instrumentId) {
    final options = conditionsForInstrument(instrumentId);
    var on = 0;
    for (final option in options) {
      if (option.isCount) {
        if (conditionCountOf(option.id) > 0) {
          on += 1;
        }
      } else if (conditionStateOf(option.id) == TriState.satisfied) {
        on += 1;
      }
    }

    return 'オン $on 件 / 全 ${options.length} 件';
  }

  /// 会計の記録（新しい順）。
  List<AnnualRecord> get annualRecords => _records;

  /// 今年の会計の集計（D-122）。12月末で締め、1月から新しい年になる。
  AnnualRecordSummary? get annualRecordSummary {
    if (_catalog.isEmpty) {
      return null;
    }

    final year = currentJstDate().year;
    final cached = _recordSummary;
    if (cached != null && cached.year == year) {
      return cached;
    }

    _recordSummary = _recordSummaryUseCase.execute(
      catalog: _catalog,
      directory: _directory,
      records: _records,
      year: year,
      conditionContext: conditionContext,
      hiddenCardIds: _preferences.hiddenCardIds,
    );

    return _recordSummary;
  }

  /// 会計を1件記録する（D-122）。
  Future<void> addAnnualRecord({
    required MerchantEntry merchant,
    required int amountYen,
  }) async {
    if (amountYen < 1) {
      return;
    }

    final date = currentJstDate();
    final id = '${date.toString()}-${merchant.id.value}-'
        '${DateTime.now().microsecondsSinceEpoch}';

    final next = <AnnualRecord>[
      AnnualRecord(
        id: id,
        date: date,
        merchantId: merchant.id.value,
        merchantName: merchant.name,
        amountYen: amountYen,
      ),
      ..._records,
    ];

    _records = next;
    _recordSummary = null;
    notifyListeners();
    await _recordStore.save(next);
  }

  /// 会計の記録を1件消す。
  Future<void> removeAnnualRecord(String recordId) async {
    final next = <AnnualRecord>[
      for (final record in _records)
        if (record.id != recordId) record,
    ];

    _records = next;
    _recordSummary = null;
    notifyListeners();
    await _recordStore.save(next);
  }

  /// 金額と店舗を指定して比較する（計算タブ専用・D-115）。
  ///
  /// 店舗タブの基準額（1万円）ではなく、利用者が入力した金額で
  /// その店舗の還元額をカードごとに出す。
  void compareAtMerchantWithAmount({
    required MerchantEntry merchant,
    required MoneyYen amount,
  }) {
    _selectedMerchant = merchant;
    _ranking = _applyVisibility(
      _useCase.execute(
        catalog: _catalog,
        amount: amount,
        transactionDate: currentJstDate(),
        conditionContext: conditionContext,
        merchantId: merchant.id,
        merchantGroupIds: merchant.groupIds,
        categoryIds: merchant.categoryIds,
      ),
    );
    notifyListeners();
  }

  /// 記録の還元額を出すための評価（状態を変えない・D-121）。
  ///
  /// 計算タブのように画面の選択を書き換えず、金額と店舗だけから
  /// カードごとの還元額を求める。年間タブが会計記録の評価に使う。
  RewardRanking evaluateAtMerchant({
    required MerchantEntry merchant,
    required MoneyYen amount,
    CalculationDate? date,
  }) {
    return _applyVisibility(
      _useCase.execute(
        catalog: _catalog,
        amount: amount,
        transactionDate: date ?? currentJstDate(),
        conditionContext: conditionContext,
        merchantId: merchant.id,
        merchantGroupIds: merchant.groupIds,
        categoryIds: merchant.categoryIds,
      ),
    );
  }

  /// 店舗IDから店舗を引く（記録の表示用）。
  MerchantEntry? merchantById(String merchantId) {
    for (final merchant in _directory.merchants) {
      if (merchant.id.value == merchantId) {
        return merchant;
      }
    }

    return null;
  }

  /// 年間の還元額を概算する（年間タブ専用・D-102）。
  void computeAnnualSummary({required MoneyYen annualSpend}) {
    _annualSummary = _annualUseCase.execute(
      catalog: _catalog,
      annualSpend: annualSpend,
      transactionDate: currentJstDate(),
      conditionContext: conditionContext,
      hiddenCardIds: _preferences.hiddenCardIds,
    );
    notifyListeners();
  }

  /// カードをランキングに出す／出さないを保存する（D-082）。
  Future<void> setCardVisible(String instrumentId, bool visible) async {
    _bestRateCache.clear();
    _recordSummary = null;
    final hidden = _preferences.hiddenCardIds.toSet();
    if (visible) {
      hidden.remove(instrumentId);
    } else {
      hidden.add(instrumentId);
    }

    await _update(_preferences.copyWith(hiddenCardIds: hidden));
  }

  /// 条件の状態を保存する（D-101）。
  Future<void> setConditionState(String conditionId, TriState state) async {
    _bestRateCache.clear();
    _recordSummary = null;
    final states = Map<String, TriState>.of(_preferences.conditionStates)
      ..[conditionId] = state;

    await _update(_preferences.copyWith(conditionStates: states));
  }

  /// カテゴリの並び順を保存する（D-095）。
  Future<void> saveCategoryOrder(List<MerchantCategory> categories) async {
    await _update(
      _preferences.copyWith(
        categoryOrder: <String>[
          for (final category in categories) category.id.value,
        ],
      ),
    );
  }

  /// カテゴリ内の店舗の並び順を保存する（D-099）。
  Future<void> saveMerchantOrder(
    StableId categoryId,
    List<MerchantEntry> merchants,
  ) async {
    final order = Map<String, List<String>>.of(_preferences.merchantOrder)
      ..[categoryId.value] = <String>[
        for (final merchant in merchants) merchant.id.value,
      ];

    await _update(_preferences.copyWith(merchantOrder: order));
  }

  /// 設定を反映して保存する。並べ替えの評価結果は作り直す。
  Future<void> _update(UserPreferences preferences) async {
    _preferences = preferences;
    _bestRateCache.clear();
    _ranking = _ranking == null ? null : _recomputeRanking();
    _annualSummary = null;
    notifyListeners();

    await _preferencesStore.save(_preferences);
  }

  RewardRanking? _recomputeRanking() {
    final merchant = _selectedMerchant;
    if (merchant == null) {
      return null;
    }

    return _applyVisibility(
      _useCase.execute(
        catalog: _catalog,
        amount: RewardRankingUseCase.comparisonAmount,
        transactionDate: currentJstDate(),
        conditionContext: conditionContext,
        merchantId: merchant.id,
        merchantGroupIds: merchant.groupIds,
        categoryIds: merchant.categoryIds,
      ),
    );
  }

  /// ランキングに出すカードだけに絞る（D-082）。
  RewardRanking _applyVisibility(RewardRanking ranking) {
    final confirmed = <RewardRankingEntry>[
      for (final entry in ranking.confirmed)
        if (isCardVisible(entry.instrumentId.value)) entry,
    ];
    final estimated = <RewardRankingEntry>[
      for (final entry in ranking.estimated)
        if (isCardVisible(entry.instrumentId.value)) entry,
    ];

    return RewardRanking(
      confirmed: confirmed,
      estimated: estimated,
      amount: ranking.amount,
      baselineInstrumentId: ranking.baselineInstrumentId,
    );
  }

  /// 金額を指定して比較する（年間タブ用）。
  void showRankingFor({required MoneyYen amount}) {
    _ranking = _applyVisibility(
      _useCase.execute(
        catalog: _catalog,
        amount: amount,
        transactionDate: currentJstDate(),
        conditionContext: conditionContext,
      ),
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

import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/calculation/period_aggregation_snapshot.dart';
import 'package:bestpay/domain/calculation/condition_evaluation_context.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_evaluation_input.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_evaluation_result.dart';
import 'package:bestpay/domain/calculation/reward_rule_set_evaluator.dart';
import 'package:bestpay/domain/catalog/catalog.dart';
import 'package:bestpay/domain/catalog/models/catalog_types.dart';
import 'package:bestpay/domain/catalog/models/payment_instrument_models.dart';
import 'package:bestpay/domain/catalog/models/reward_rule_models.dart';
import 'package:bestpay/domain/ranking/period_increment_calculator.dart';
import 'package:bestpay/domain/ranking/reward_ranking.dart';

/// 基準カード（みずほ楽天カード）と比較したランキングを作る（D-084）。
///
/// 判定は「その1回の支払い単独」で完結する。月間・年間の合計額は一切入力に
/// とらない（D-085）。期間集計のルールは「その支払いの時点で期間の利用額が
/// 0円から始まる」として評価するため、結果は入力なしで常に確定する（D-087）。
///
/// This evaluator performs no I/O and uses no floating point arithmetic. It
/// compares every card through the existing reward calculation engine and
/// keeps unknown conditions out of the confirmed total (D-50, D-44).
final class RewardRankingEvaluator {
  const RewardRankingEvaluator({
    RewardRuleSetEvaluator ruleSetEvaluator = const RewardRuleSetEvaluator(),
    PeriodIncrementCalculator periodIncrementCalculator =
        const PeriodIncrementCalculator(),
  })  : _ruleSetEvaluator = ruleSetEvaluator,
        _periodIncrementCalculator = periodIncrementCalculator;

  final RewardRuleSetEvaluator _ruleSetEvaluator;
  final PeriodIncrementCalculator _periodIncrementCalculator;

  /// Evaluates one transaction of [amount] and compares every card against
  /// [baselineCardId].
  RewardRanking evaluate({
    required Catalog catalog,
    required MoneyYen amount,
    required CalculationDate transactionDate,
    ConditionEvaluationContext? conditionContext,
    StableId? baselineCardId,
    StableId? merchantId,
    Iterable<StableId> merchantGroupIds = const <StableId>[],
    Iterable<StableId> categoryIds = const <StableId>[],
  }) {
    final context = conditionContext ?? ConditionEvaluationContext();
    final baseline = baselineCardId ?? baselineInstrumentId;

    final instruments = catalog.paymentInstrumentsById.values.toList()
      ..sort((left, right) => left.id.value.compareTo(right.id.value));

    final evaluated = <RewardRankingEntry>[];
    for (final instrument in instruments) {
      evaluated.add(
        _evaluateInstrument(
          catalog: catalog,
          instrument: instrument,
          amount: amount,
          transactionDate: transactionDate,
          conditionContext: context,
          merchantId: merchantId,
          merchantGroupIds: merchantGroupIds,
          categoryIds: categoryIds,
        ),
      );
    }

    // 基準カードがカタログに無い場合は比較を成立させない（基準0円と
    // みなして全カードを「上回る」とはしない）。
    final baselineValueMicros = _valueOf(evaluated, baseline);
    final compared = evaluated
        .map(
          (entry) => entry.withBaselineComparison(
            isBaseline: entry.instrumentId == baseline,
            beatsBaseline: baselineValueMicros != null &&
                entry.instrumentId != baseline &&
                entry.confirmedValue.micros > baselineValueMicros,
            baselineDeltaMicros: baselineValueMicros == null
                ? 0
                : entry.confirmedValue.micros - baselineValueMicros,
          ),
        )
        .toList();

    final confirmed = <RewardRankingEntry>[];
    final estimated = <RewardRankingEntry>[];
    for (final entry in compared) {
      if (entry.confidence == RewardConfidence.estimated) {
        estimated.add(entry);
      } else {
        confirmed.add(entry);
      }
    }

    confirmed.sort(compareRankingEntries);
    estimated.sort(compareRankingEntries);

    return RewardRanking(
      confirmed: confirmed,
      estimated: estimated,
      amount: amount,
      baselineInstrumentId: baseline,
    );
  }

  int? _valueOf(List<RewardRankingEntry> entries, StableId instrumentId) {
    for (final entry in entries) {
      if (entry.instrumentId == instrumentId) {
        return entry.confirmedValue.micros;
      }
    }

    return null;
  }

  RewardRankingEntry _evaluateInstrument({
    required Catalog catalog,
    required PaymentInstrument instrument,
    required MoneyYen amount,
    required CalculationDate transactionDate,
    required ConditionEvaluationContext conditionContext,
    required StableId? merchantId,
    required Iterable<StableId> merchantGroupIds,
    required Iterable<StableId> categoryIds,
  }) {
    final rules = catalog.rulesApplicableToInstrument(instrument.id);

    if (rules.isEmpty) {
      return _emptyEntry(instrument: instrument, amount: amount);
    }

    final input = RewardEvaluationInput(
      amount: amount,
      instrumentId: instrument.id,
      modeId: null,
      routeId: null,
      merchantId: merchantId,
      merchantGroupIds: merchantGroupIds,
      categoryIds: categoryIds,
      conditionContext: conditionContext,
      transactionDate: transactionDate,
      settlementDataReceivedDate: transactionDate,
      periodAggregationSnapshots: _buildPeriodSnapshots(
        rules: rules,
        amount: amount,
        transactionDate: transactionDate,
      ),
    );

    final evaluation = _ruleSetEvaluator.evaluateResult(
      rules: rules,
      input: input,
    );

    return evaluation.fold<RewardRankingEntry>(
      onSuccess: (result) => _toEntry(
        catalog: catalog,
        instrument: instrument,
        amount: amount,
        result: result,
      ),
      onFailure: (_) => _emptyEntry(
        instrument: instrument,
        amount: amount,
        hasUnresolvedConditions: true,
      ),
    );
  }

  /// Builds the period state for a single transaction.
  ///
  /// 利用者は月間・年間の合計額を入力しない（D-085）。そこで期間集計の
  /// ルールは「その期間の利用額が0円の状態から、この支払い1回だけを行う」
  /// として評価する。増分は `floor((0 + A) / U) - floor(0 / U)` となり、
  /// 切り捨ては1回分しか効かないため過大評価にならない（D-087）。
  Map<StableId, PeriodAggregationSnapshot> _buildPeriodSnapshots({
    required List<RewardRule> rules,
    required MoneyYen amount,
    required CalculationDate transactionDate,
  }) {
    final snapshots = <StableId, PeriodAggregationSnapshot>{};
    final periodEnd = _nextMonthStart(transactionDate);

    if (periodEnd == null) {
      return snapshots;
    }

    for (final rule in rules) {
      final aggregation = rule.aggregation;
      if (aggregation.scope == RewardAggregationScope.transaction) {
        continue;
      }

      final key = aggregation.aggregationKey;
      if (key == null) {
        continue;
      }

      final increment = _periodIncrementCalculator.compute(
        calculation: rule.calculation,
        periodSpendBefore: MoneyYen.zero,
        amount: amount,
      );

      increment.fold<void>(
        onSuccess: (value) {
          try {
            snapshots[key] = PeriodAggregationSnapshot.validated(
              periodStart: transactionDate,
              periodEndExclusive: periodEnd,
              periodSpendBefore: MoneyYen.zero,
              periodSpendAfter: amount,
              pointsBefore: value.pointsBefore,
              pointsAfter: value.pointsAfter,
              currentIncrement: value.increment,
              confidence: PeriodDataConfidence.exact,
            );
          } on ArgumentError {
            // An inconsistent period stays unknown.
          }
        },
        onFailure: (_) {
          // The rule keeps its period state missing and stays unknown.
        },
      );
    }

    return snapshots;
  }

  /// The first day of the month after [date], used as the period end.
  CalculationDate? _nextMonthStart(CalculationDate date) {
    final year = date.month == 12 ? date.year + 1 : date.year;
    final month = date.month == 12 ? 1 : date.month + 1;

    return CalculationDate.create(year, month, 1).fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
  }

  RewardRankingEntry _toEntry({
    required Catalog catalog,
    required PaymentInstrument instrument,
    required MoneyYen amount,
    required RewardRuleSetEvaluationResult result,
  }) {
    final awards = <ProgramPointAward>[];
    var totalPoints = PointAmount.zero;
    var valueMicros = 0;
    var hasUnconvertiblePoints = false;

    for (final programEntry in result.pointsByProgram.entries) {
      final program = catalog.pointProgramsById[programEntry.key];
      final points = programEntry.value;
      final converted = program?.valueOf(points);

      if (converted == null) {
        hasUnconvertiblePoints = true;
      } else {
        valueMicros += converted.micros;
      }

      awards.add(
        ProgramPointAward(
          programId: programEntry.key,
          programName: program?.name ?? programEntry.key.value,
          unitName: program?.unitName ?? 'pt',
          points: points,
          convertedValue: converted,
        ),
      );

      totalPoints = totalPoints + points;
    }

    awards.sort(
      (left, right) => left.programId.value.compareTo(right.programId.value),
    );

    var stepCount = 0;
    var hasEstimatedSteps = false;
    var hasUnresolvedConditions = false;

    for (final ruleResult in result.ruleResults) {
      if (ruleResult.eligibility == TriState.unknown) {
        hasUnresolvedConditions = true;
      }

      final points = ruleResult.points;
      if (ruleResult.isCalculated && points != null && points.points > 0) {
        stepCount += 1;

        if (ruleResult.confidence == RewardConfidence.estimated) {
          hasEstimatedSteps = true;
        }
      }
    }

    return RewardRankingEntry(
      instrumentId: instrument.id,
      instrumentName: instrument.name,
      programAwards: List<ProgramPointAward>.unmodifiable(awards),
      totalPoints: totalPoints,
      confirmedValue: MicrosYen(valueMicros),
      effectiveRate: _effectiveRate(valueMicros: valueMicros, amount: amount),
      confidence:
          hasEstimatedSteps ? RewardConfidence.estimated : RewardConfidence.confirmed,
      stepCount: stepCount,
      annualFee: instrument.annualFee,
      hasUnconvertiblePoints: hasUnconvertiblePoints,
      hasUnresolvedConditions: hasUnresolvedConditions,
    );
  }

  RewardRankingEntry _emptyEntry({
    required PaymentInstrument instrument,
    required MoneyYen amount,
    bool hasUnresolvedConditions = false,
  }) {
    return RewardRankingEntry(
      instrumentId: instrument.id,
      instrumentName: instrument.name,
      programAwards: const <ProgramPointAward>[],
      totalPoints: PointAmount.zero,
      confirmedValue: MicrosYen.zero,
      effectiveRate: Rational.zero,
      confidence: RewardConfidence.confirmed,
      stepCount: 0,
      annualFee: instrument.annualFee,
      hasUnconvertiblePoints: false,
      hasUnresolvedConditions: hasUnresolvedConditions,
    );
  }

  Rational _effectiveRate({
    required int valueMicros,
    required MoneyYen amount,
  }) {
    if (amount.yen <= 0) {
      return Rational.zero;
    }

    return Rational.create(
      valueMicros,
      amount.yen * MicrosYen.microsPerYen,
    ).fold(
      onSuccess: (value) => value,
      onFailure: (_) => Rational.zero,
    );
  }
}

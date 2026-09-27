import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/calculation/period_aggregation_snapshot.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';

/// 比較の基準にするカード（みずほ楽天カード）。
///
/// このアプリの判断基準は「このカードで支払う前提で、それを上回るカードが
/// あるか」である（D-084）。基準カードは保有しているだけでなく、実際の
/// 生活の既定の支払い方法であることを前提にする。
final StableId baselineInstrumentId = StableId.create('mizuho_rakuten_card').fold(
  onSuccess: (value) => value,
  onFailure: (_) => throw StateError('The baseline instrument id is invalid.'),
);

/// 期間集計の入力を表す。第1期のランキングでは使用しない（D-085）。
///
/// ランキングは「1回の支払い単独」で完結するため、月間・年間の合計額は
/// 一切参照しない。この型は将来の年間タブ用に残している。
final class PeriodSpendInput {
  const PeriodSpendInput({
    required this.periodStart,
    required this.periodEndExclusive,
    required this.periodSpendBefore,
    this.confidence = PeriodDataConfidence.userEntered,
  });

  final CalculationDate periodStart;
  final CalculationDate periodEndExclusive;
  final MoneyYen periodSpendBefore;
  final PeriodDataConfidence confidence;
}

/// Points awarded in one point program, with its own yen conversion (D-51).
final class ProgramPointAward {
  const ProgramPointAward({
    required this.programId,
    required this.programName,
    required this.unitName,
    required this.points,
    required this.convertedValue,
  });

  final StableId programId;
  final String programName;
  final String unitName;
  final PointAmount points;

  /// Exact yen value, or null when the program value is not fixed.
  final MicrosYen? convertedValue;
}

/// One card's confirmed reward for a single transaction (D-084, D-085).
final class RewardRankingEntry {
  const RewardRankingEntry({
    required this.instrumentId,
    required this.instrumentName,
    required this.programAwards,
    required this.totalPoints,
    required this.confirmedValue,
    required this.effectiveRate,
    required this.confidence,
    required this.stepCount,
    required this.annualFee,
    required this.hasUnconvertiblePoints,
    required this.hasUnresolvedConditions,
    this.isBaseline = false,
    this.beatsBaseline = false,
    this.baselineDeltaMicros = 0,
  });

  final StableId instrumentId;
  final String instrumentName;

  /// Per-program breakdown. Points are never merged across programs (D-51).
  final List<ProgramPointAward> programAwards;

  final PointAmount totalPoints;

  /// Exact yen-equivalent value of the confirmed points (D-41).
  final MicrosYen confirmedValue;

  /// [confirmedValue] divided by the transaction amount, as an exact ratio.
  final Rational effectiveRate;

  final RewardConfidence confidence;

  /// Number of confirmed reward steps that contributed points.
  final int stepCount;

  /// Annual fee, used only as a tie-break (D-54).
  final MoneyYen annualFee;

  /// True when at least one program could not be converted into yen.
  final bool hasUnconvertiblePoints;

  /// True when some rules stayed unknown (for example missing conditions).
  final bool hasUnresolvedConditions;

  /// True for the comparison baseline card itself (D-084).
  final bool isBaseline;

  /// True when this card earns strictly more than the baseline card.
  final bool beatsBaseline;

  /// Difference against the baseline card, in micros of yen.
  final int baselineDeltaMicros;

  /// Copy with the baseline comparison applied.
  RewardRankingEntry withBaselineComparison({
    required bool isBaseline,
    required bool beatsBaseline,
    required int baselineDeltaMicros,
  }) {
    return RewardRankingEntry(
      instrumentId: instrumentId,
      instrumentName: instrumentName,
      programAwards: programAwards,
      totalPoints: totalPoints,
      confirmedValue: confirmedValue,
      effectiveRate: effectiveRate,
      confidence: confidence,
      stepCount: stepCount,
      annualFee: annualFee,
      hasUnconvertiblePoints: hasUnconvertiblePoints,
      hasUnresolvedConditions: hasUnresolvedConditions,
      isBaseline: isBaseline,
      beatsBaseline: beatsBaseline,
      baselineDeltaMicros: baselineDeltaMicros,
    );
  }
}

/// The complete comparison result for one transaction amount.
///
/// すべてのカードが「その1回の支払い」で確定評価される（D-085, D-087）。
final class RewardRanking {
  RewardRanking({
    required Iterable<RewardRankingEntry> confirmed,
    required Iterable<RewardRankingEntry> estimated,
    required this.amount,
    this.baselineInstrumentId,
  })  : confirmed = List<RewardRankingEntry>.unmodifiable(confirmed),
        estimated = List<RewardRankingEntry>.unmodifiable(estimated);

  /// Entries whose value is confirmed, ordered by the D-42 tie-break chain.
  final List<RewardRankingEntry> confirmed;

  /// Entries that still depend on unknown conditions.
  final List<RewardRankingEntry> estimated;

  final MoneyYen amount;

  /// The card every other card is compared against (D-084).
  final StableId? baselineInstrumentId;

  bool get isEmpty => confirmed.isEmpty && estimated.isEmpty;

  bool get isNotEmpty => !isEmpty;

  bool get hasUnresolvedConditions =>
      confirmed.any((entry) => entry.hasUnresolvedConditions) ||
      estimated.any((entry) => entry.hasUnresolvedConditions);

  /// All entries in rank order.
  List<RewardRankingEntry> get allEntries =>
      <RewardRankingEntry>[...confirmed, ...estimated];

  /// The baseline card's own entry, when it exists in the catalog.
  RewardRankingEntry? get baselineEntry {
    final target = baselineInstrumentId;
    if (target == null) {
      return null;
    }

    for (final entry in allEntries) {
      if (entry.instrumentId == target) {
        return entry;
      }
    }

    return null;
  }

  /// Cards that earn strictly more than the baseline card, best first (D-086).
  List<RewardRankingEntry> get betterThanBaseline =>
      allEntries.where((entry) => entry.beatsBaseline).toList();

  /// The single best card for this transaction, when one can be chosen.
  RewardRankingEntry? get bestEntry {
    final entries = allEntries;
    if (entries.isEmpty) {
      return null;
    }

    return entries.first;
  }

  /// True when no card beats the baseline, so the baseline stays the choice.
  bool get baselineRemainsBest => betterThanBaseline.isEmpty;
}

/// Ordering defined by decision D-42.
///
/// Confirmed value descending, confidence descending, step count ascending,
/// annual fee ascending, and finally the instrument identifier in dictionary
/// order. The ordering is total because instrument identifiers are unique.
int compareRankingEntries(RewardRankingEntry left, RewardRankingEntry right) {
  final valueComparison = right.confirmedValue.compareTo(left.confirmedValue);
  if (valueComparison != 0) {
    return valueComparison;
  }

  final confidenceComparison = right.confidence.rankWeight.compareTo(
    left.confidence.rankWeight,
  );
  if (confidenceComparison != 0) {
    return confidenceComparison;
  }

  final stepComparison = left.stepCount.compareTo(right.stepCount);
  if (stepComparison != 0) {
    return stepComparison;
  }

  final feeComparison = left.annualFee.compareTo(right.annualFee);
  if (feeComparison != 0) {
    return feeComparison;
  }

  return left.instrumentId.value.compareTo(right.instrumentId.value);
}

/// Presentation-neutral helpers for [RewardConfidence] (D-56).
extension RewardConfidenceRanking on RewardConfidence {
  /// Higher values rank earlier in a tie (D-42).
  int get rankWeight {
    return switch (this) {
      RewardConfidence.confirmed => 4,
      RewardConfidence.estimated => 3,
      RewardConfidence.conditional => 2,
      RewardConfidence.unknown => 1,
      RewardConfidence.ineligible => 0,
    };
  }

  /// Short Japanese label shown next to a result.
  String get label {
    return switch (this) {
      RewardConfidence.confirmed => '確定',
      RewardConfidence.estimated => '推定',
      RewardConfidence.conditional => '条件付き',
      RewardConfidence.unknown => '不明',
      RewardConfidence.ineligible => '対象外',
    };
  }
}

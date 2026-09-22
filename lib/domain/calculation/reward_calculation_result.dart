import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';

/// Immutable result of evaluating one reward calculation.
///
/// A calculated result has a non-negative [points] value. An unavailable
/// result has no points because the required calculation input is missing or
/// a condition remains unresolved. Rule-definition failures are represented
/// separately by AppFailure.
final class RewardCalculationResult {
  RewardCalculationResult.calculated({
    required PointAmount points,
    RewardConfidence confidence = RewardConfidence.confirmed,
    Iterable<RewardReasonCode> reasonCodes = const <RewardReasonCode>[
      RewardReasonCode.applied
    ],
  })  : points = points,
        confidence = confidence,
        reasonCodes = _freezeReasonCodes(reasonCodes) {
    if (points.isNegative) {
      throw ArgumentError.value(
        points,
        'points',
        'Calculated reward points must not be negative.',
      );
    }

    if (confidence == RewardConfidence.unknown ||
        confidence == RewardConfidence.conditional ||
        confidence == RewardConfidence.ineligible) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'Calculated results must be confirmed or estimated.',
      );
    }
  }

  RewardCalculationResult.unavailable({
    required this.confidence,
    required Iterable<RewardReasonCode> reasonCodes,
  })  : points = null,
        reasonCodes = _freezeReasonCodes(reasonCodes) {
    if (confidence != RewardConfidence.unknown &&
        confidence != RewardConfidence.conditional) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'Unavailable results must be unknown or conditional.',
      );
    }
  }

  final PointAmount? points;
  final RewardConfidence confidence;
  final List<RewardReasonCode> reasonCodes;

  bool get isCalculated => points != null;

  static List<RewardReasonCode> _freezeReasonCodes(
    Iterable<RewardReasonCode> values,
  ) {
    final result = List<RewardReasonCode>.of(values);

    if (result.isEmpty) {
      throw ArgumentError.value(
        values,
        'reasonCodes',
        'At least one reason code is required.',
      );
    }

    if (result.toSet().length != result.length) {
      throw ArgumentError.value(
        values,
        'reasonCodes',
        'Reason codes must be unique.',
      );
    }

    return List<RewardReasonCode>.unmodifiable(result);
  }
}

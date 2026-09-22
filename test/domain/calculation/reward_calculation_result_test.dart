import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/point_amount.dart';
import 'package:bestpay/domain/calculation/reward_calculation_result.dart';
import 'package:bestpay/domain/calculation/reward_confidence.dart';
import 'package:bestpay/domain/calculation/reward_reason_code.dart';
import 'package:bestpay/domain/calculation/threshold_period_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RewardConfidence', () {
    test('uses stable values', () {
      expect(
        RewardConfidence.values.map((value) => value.value),
        <String>[
          'confirmed',
          'estimated',
          'conditional',
          'unknown',
          'ineligible',
        ],
      );
    });
  });

  group('RewardReasonCode', () {
    test('uses the documented stable values', () {
      expect(
        RewardReasonCode.values.map((value) => value.value),
        <String>[
          'applied',
          'selectorMismatch',
          'excluded',
          'outsideValidityPeriod',
          'missingDateBasis',
          'conditionNotSatisfied',
          'conditionUnknown',
          'replaced',
          'suppressed',
          'exclusiveGroupLost',
          'dependencyNotSatisfied',
          'periodStateMissing',
          'capApplied',
          'mirrorSourceMissing',
          'invalidRule',
          'noRewardCalculation',
          'thresholdNotCrossed',
          'thresholdAwardLimitReached',
        ],
      );
    });
  });

  group('RewardCalculationResult', () {
    test('represents a confirmed calculated result', () {
      final result = RewardCalculationResult.calculated(
        points: const PointAmount(25),
      );

      expect(result.isCalculated, isTrue);
      expect(result.points, const PointAmount(25));
      expect(result.confidence, RewardConfidence.confirmed);
      expect(
        result.reasonCodes,
        const <RewardReasonCode>[RewardReasonCode.applied],
      );
    });

    test('represents an unavailable period-state result', () {
      final result = RewardCalculationResult.unavailable(
        confidence: RewardConfidence.unknown,
        reasonCodes: const <RewardReasonCode>[
          RewardReasonCode.periodStateMissing,
        ],
      );

      expect(result.isCalculated, isFalse);
      expect(result.points, isNull);
      expect(result.confidence, RewardConfidence.unknown);
    });

    test('defensively copies and freezes reason codes', () {
      final reasons = <RewardReasonCode>[
        RewardReasonCode.thresholdNotCrossed,
      ];
      final result = RewardCalculationResult.calculated(
        points: PointAmount.zero,
        reasonCodes: reasons,
      );

      reasons.add(RewardReasonCode.applied);

      expect(
        result.reasonCodes,
        const <RewardReasonCode>[
          RewardReasonCode.thresholdNotCrossed,
        ],
      );
      expect(
        () => result.reasonCodes.add(RewardReasonCode.applied),
        throwsUnsupportedError,
      );
    });

    test('rejects negative calculated points', () {
      expect(
        () => RewardCalculationResult.calculated(
          points: const PointAmount(-1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects incompatible confidence states', () {
      expect(
        () => RewardCalculationResult.calculated(
          points: PointAmount.zero,
          confidence: RewardConfidence.unknown,
        ),
        throwsArgumentError,
      );

      expect(
        () => RewardCalculationResult.unavailable(
          confidence: RewardConfidence.confirmed,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.periodStateMissing,
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty and duplicate reason-code lists', () {
      expect(
        () => RewardCalculationResult.calculated(
          points: PointAmount.zero,
          reasonCodes: const <RewardReasonCode>[],
        ),
        throwsArgumentError,
      );

      expect(
        () => RewardCalculationResult.calculated(
          points: PointAmount.zero,
          reasonCodes: const <RewardReasonCode>[
            RewardReasonCode.applied,
            RewardReasonCode.applied,
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('ThresholdPeriodSnapshot', () {
    test('stores read-only threshold inputs', () {
      final snapshot = ThresholdPeriodSnapshot.validated(
        periodSpendBefore: const MoneyYen(900),
        awardsConsumed: 0,
      );

      expect(snapshot.periodSpendBefore, const MoneyYen(900));
      expect(snapshot.awardsConsumed, 0);
    });

    test('rejects negative period spend and consumed count', () {
      expect(
        () => ThresholdPeriodSnapshot.validated(
          periodSpendBefore: const MoneyYen(-1),
          awardsConsumed: 0,
        ),
        throwsArgumentError,
      );

      expect(
        () => ThresholdPeriodSnapshot.validated(
          periodSpendBefore: MoneyYen.zero,
          awardsConsumed: -1,
        ),
        throwsArgumentError,
      );
    });
  });
}

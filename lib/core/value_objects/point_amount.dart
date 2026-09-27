/// An immutable amount represented in whole points.
///
/// Negative values are allowed so cancellations, adjustments, and differences
/// can be represented. Domain-specific awarded points may impose a
/// non-negative constraint separately.
final class PointAmount implements Comparable<PointAmount> {
  const PointAmount(this.points);

  static const PointAmount zero = PointAmount(0);

  final int points;

  bool get isZero => points == 0;

  bool get isNegative => points < 0;

  PointAmount operator -() => PointAmount(-points);

  PointAmount operator +(PointAmount other) {
    return PointAmount(points + other.points);
  }

  PointAmount operator -(PointAmount other) {
    return PointAmount(points - other.points);
  }

  PointAmount operator *(int multiplier) {
    return PointAmount(points * multiplier);
  }

  @override
  int compareTo(PointAmount other) {
    return points.compareTo(other.points);
  }

  bool operator <(PointAmount other) => compareTo(other) < 0;

  bool operator <=(PointAmount other) => compareTo(other) <= 0;

  bool operator >(PointAmount other) => compareTo(other) > 0;

  bool operator >=(PointAmount other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PointAmount && points == other.points;
  }

  @override
  int get hashCode => points.hashCode;

  @override
  String toString() => 'PointAmount($points)';
}

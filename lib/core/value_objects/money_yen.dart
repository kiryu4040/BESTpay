/// An immutable amount represented in whole Japanese yen.
///
/// Negative values are allowed so adjustments, cancellations, and differences
/// can be represented. Domain-specific purchase amounts may impose a
/// non-negative constraint separately.
final class MoneyYen implements Comparable<MoneyYen> {
  const MoneyYen(this.yen);

  static const MoneyYen zero = MoneyYen(0);

  final int yen;

  bool get isZero => yen == 0;

  bool get isNegative => yen < 0;

  MoneyYen operator -() => MoneyYen(-yen);

  MoneyYen operator +(MoneyYen other) {
    return MoneyYen(yen + other.yen);
  }

  MoneyYen operator -(MoneyYen other) {
    return MoneyYen(yen - other.yen);
  }

  MoneyYen operator *(int multiplier) {
    return MoneyYen(yen * multiplier);
  }

  @override
  int compareTo(MoneyYen other) {
    return yen.compareTo(other.yen);
  }

  bool operator <(MoneyYen other) => compareTo(other) < 0;

  bool operator <=(MoneyYen other) => compareTo(other) <= 0;

  bool operator >(MoneyYen other) => compareTo(other) > 0;

  bool operator >=(MoneyYen other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is MoneyYen && yen == other.yen;
  }

  @override
  int get hashCode => yen.hashCode;

  @override
  String toString() => 'MoneyYen($yen)';
}

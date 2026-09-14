/// Explicit rounding policies for exact integer-based calculations.
///
/// Persist the enum [name], never its numeric index.
enum RoundingMode {
  /// Discards the fractional part and moves toward zero.
  towardZero,

  /// Rounds toward negative infinity.
  floor,

  /// Rounds toward positive infinity.
  ceiling,

  /// Rounds the nearest value, with exact halves moving away from zero.
  halfAwayFromZero,
}

/// A three-valued condition result.
///
/// [unknown] must never be silently treated as [notSatisfied].
enum TriState {
  satisfied,
  notSatisfied,
  unknown;

  /// Logical negation that preserves an unknown state.
  TriState get not {
    return switch (this) {
      TriState.satisfied => TriState.notSatisfied,
      TriState.notSatisfied => TriState.satisfied,
      TriState.unknown => TriState.unknown,
    };
  }

  /// Three-valued logical AND.
  ///
  /// A known false result takes priority, followed by unknown.
  TriState and(TriState other) {
    if (this == TriState.notSatisfied || other == TriState.notSatisfied) {
      return TriState.notSatisfied;
    }

    if (this == TriState.unknown || other == TriState.unknown) {
      return TriState.unknown;
    }

    return TriState.satisfied;
  }

  /// Three-valued logical OR.
  ///
  /// A known true result takes priority, followed by unknown.
  TriState or(TriState other) {
    if (this == TriState.satisfied || other == TriState.satisfied) {
      return TriState.satisfied;
    }

    if (this == TriState.unknown || other == TriState.unknown) {
      return TriState.unknown;
    }

    return TriState.notSatisfied;
  }

  /// Converts to a nullable boolean without losing the unknown state.
  bool? toNullableBool() {
    return switch (this) {
      TriState.satisfied => true,
      TriState.notSatisfied => false,
      TriState.unknown => null,
    };
  }

  /// Converts a nullable boolean while preserving null as unknown.
  static TriState fromNullableBool(bool? value) {
    return switch (value) {
      true => TriState.satisfied,
      false => TriState.notSatisfied,
      null => TriState.unknown,
    };
  }
}

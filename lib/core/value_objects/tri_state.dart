/// A four-valued condition result.
///
/// [unknown] means that the condition cannot currently be determined.
///
/// [notApplicable] means that the condition does not apply to the current
/// instrument, route, merchant, transaction, or rule.
///
/// Neither [unknown] nor [notApplicable] may be silently treated as
/// [notSatisfied].
///
/// Persist this value by its stable enum name. Do not persist the enum index.
enum TriState {
  satisfied,
  notSatisfied,
  unknown,
  notApplicable;

  /// Logical negation.
  ///
  /// Negation preserves [unknown] and [notApplicable].
  TriState get not {
    return switch (this) {
      TriState.satisfied => TriState.notSatisfied,
      TriState.notSatisfied => TriState.satisfied,
      TriState.unknown => TriState.unknown,
      TriState.notApplicable => TriState.notApplicable,
    };
  }

  /// Four-valued logical AND.
  ///
  /// Precedence:
  ///
  /// 1. [notSatisfied]
  /// 2. [unknown]
  /// 3. [notApplicable]
  /// 4. [satisfied]
  TriState and(TriState other) {
    if (this == TriState.notSatisfied || other == TriState.notSatisfied) {
      return TriState.notSatisfied;
    }

    if (this == TriState.unknown || other == TriState.unknown) {
      return TriState.unknown;
    }

    if (this == TriState.notApplicable || other == TriState.notApplicable) {
      return TriState.notApplicable;
    }

    return TriState.satisfied;
  }

  /// Four-valued logical OR.
  ///
  /// Precedence:
  ///
  /// 1. [satisfied]
  /// 2. [unknown]
  /// 3. [notApplicable]
  /// 4. [notSatisfied]
  TriState or(TriState other) {
    if (this == TriState.satisfied || other == TriState.satisfied) {
      return TriState.satisfied;
    }

    if (this == TriState.unknown || other == TriState.unknown) {
      return TriState.unknown;
    }

    if (this == TriState.notApplicable || other == TriState.notApplicable) {
      return TriState.notApplicable;
    }

    return TriState.notSatisfied;
  }

  /// Converts this value to a nullable boolean.
  ///
  /// Both [unknown] and [notApplicable] become null because a nullable
  /// boolean cannot preserve the distinction between those two states.
  ///
  /// Use the enum name for lossless serialization.
  bool? toNullableBool() {
    return switch (this) {
      TriState.satisfied => true,
      TriState.notSatisfied => false,
      TriState.unknown => null,
      TriState.notApplicable => null,
    };
  }

  /// Converts a nullable boolean to a [TriState].
  ///
  /// A null value becomes [unknown]. A nullable boolean cannot produce
  /// [notApplicable]; callers must select [notApplicable] explicitly.
  static TriState fromNullableBool(bool? value) {
    return switch (value) {
      true => TriState.satisfied,
      false => TriState.notSatisfied,
      null => TriState.unknown,
    };
  }
}

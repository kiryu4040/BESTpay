/// Stable, machine-readable error categories used across Maxpay v2.
///
/// Persist [name] when a stable representation is needed. Enum indexes must
/// not be persisted because inserting a value can change them.
enum AppErrorCode {
  // Common.
  unknown,
  invalidArgument,
  invalidState,
  unsupportedOperation,
  cancelled,
  timeout,

  // Data.
  notFound,
  duplicate,
  conflict,
  dataCorrupted,
  dataValidationFailed,
  incompatibleVersion,

  // Catalog.
  catalogNotFound,
  catalogReadFailed,
  catalogDecodeFailed,
  catalogValidationFailed,
  catalogVersionUnsupported,
  catalogReferenceBroken,

  // Storage.
  databaseOpenFailed,
  databaseReadFailed,
  databaseWriteFailed,
  databaseTransactionFailed,
  preferencesReadFailed,
  preferencesWriteFailed,

  // Migration.
  migrationSourceUnknown,
  migrationValidationFailed,
  migrationMappingFailed,
  migrationCommitFailed,
  migrationAlreadyRunning,
  migrationRollbackFailed,

  // Backup.
  backupReadFailed,
  backupWriteFailed,
  backupFormatUnknown,
  backupVersionUnsupported,
  backupValidationFailed,
  backupRestoreFailed,
  backupSnapshotFailed,

  // Calculation.
  calculationInputInvalid,
  calculationRuleInvalid,
  calculationConditionUnknown,
  calculationOverflow,
  calculationNonDeterministic,
}

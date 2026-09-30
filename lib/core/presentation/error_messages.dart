import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/l10n/app_localizations.dart';

/// Exhaustive on purpose (no `default`): adding a [DomainError] must break the
/// analyzer here.
String errorMessage(DomainError error, AppLocalizations l10n) {
  return switch (error) {
    ValidationError() => l10n.errorValidation,
    NotFoundError() => l10n.errorNotFound,
    DuplicateError() => l10n.errorDuplicate,
    CategoryTypeMismatchError() => l10n.errorCategoryTypeMismatch,
    CategoryInUseError() => l10n.errorCategoryInUse,
    StorageError() => l10n.errorStorage,
    NetworkError() => l10n.errorNetwork,
    BackendUnavailableError() => l10n.errorBackendUnavailable,
    AuthError(:final kind) => switch (kind) {
      AuthErrorKind.invalidEmail => l10n.errorAuthInvalidEmail,
      AuthErrorKind.invalidCode => l10n.errorAuthInvalidCode,
      AuthErrorKind.codeExpired => l10n.errorAuthCodeExpired,
      AuthErrorKind.rateLimited => l10n.errorAuthRateLimited,
      AuthErrorKind.notSignedIn => l10n.errorAuthNotSignedIn,
    },
    BiometricError(:final kind) => switch (kind) {
      BiometricErrorKind.notAvailable => l10n.errorBiometricNotAvailable,
      BiometricErrorKind.notEnrolled => l10n.errorBiometricNotEnrolled,
      BiometricErrorKind.lockedOut => l10n.errorBiometricLockedOut,
      BiometricErrorKind.cancelled => l10n.errorBiometricCancelled,
    },
    ExportError(:final reason) => switch (reason) {
      ExportErrorReason.emptyRange => l10n.errorExportEmptyRange,
      ExportErrorReason.writeFailed => l10n.errorExportWriteFailed,
      ExportErrorReason.shareFailed => l10n.errorExportShareFailed,
    },
    UnknownError() => l10n.errorUnknown,
  };
}

String validationMessage(ValidationReason reason, AppLocalizations l10n) {
  return switch (reason) {
    ValidationReason.required => l10n.validationRequired,
    ValidationReason.mustBePositive => l10n.validationMustBePositive,
    ValidationReason.tooManyDecimals => l10n.validationTooManyDecimals,
    ValidationReason.tooLong => l10n.validationTooLong,
    ValidationReason.invalidFormat => l10n.validationInvalidFormat,
    ValidationReason.notAllowed => l10n.validationNotAllowed,
  };
}

String messageFor(Object error, AppLocalizations l10n) {
  return error is DomainError ? errorMessage(error, l10n) : l10n.errorUnknown;
}

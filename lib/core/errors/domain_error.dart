/// Typed errors thrown by repositories and use cases. Presentation switches
/// over them exhaustively.
///
/// Mapping to the portfolio-wide codes: ValidationError=validation,
/// NotFoundError=notFound,
/// DuplicateError/CategoryInUseError/CategoryTypeMismatchError=conflict,
/// NetworkError/BackendUnavailableError=network,
/// AuthError(notSignedIn)=unauthorized, UnknownError/StorageError=unknown.
sealed class DomainError implements Exception {
  const DomainError();
}

enum ValidationReason {
  required,
  mustBePositive,
  tooManyDecimals,
  tooLong,
  invalidFormat,
  notAllowed,
}

final class ValidationError extends DomainError {
  const ValidationError(this.field, this.reason);
  final String field;
  final ValidationReason reason;

  @override
  String toString() => 'ValidationError($field, ${reason.name})';
}

final class NotFoundError extends DomainError {
  const NotFoundError(this.entity, [this.id]);
  final String entity;
  final String? id;

  @override
  String toString() => 'NotFoundError($entity${id == null ? '' : ', $id'})';
}

final class DuplicateError extends DomainError {
  const DuplicateError(this.entity);
  final String entity;

  @override
  String toString() => 'DuplicateError($entity)';
}

final class CategoryTypeMismatchError extends DomainError {
  const CategoryTypeMismatchError();

  @override
  String toString() => 'CategoryTypeMismatchError()';
}

final class CategoryInUseError extends DomainError {
  const CategoryInUseError();

  @override
  String toString() => 'CategoryInUseError()';
}

final class StorageError extends DomainError {
  const StorageError([this.cause]);
  final Object? cause;

  @override
  String toString() => 'StorageError($cause)';
}

final class NetworkError extends DomainError {
  const NetworkError([this.cause]);
  final Object? cause;

  @override
  String toString() => 'NetworkError($cause)';
}

final class BackendUnavailableError extends DomainError {
  const BackendUnavailableError([this.cause]);
  final Object? cause;

  @override
  String toString() => 'BackendUnavailableError($cause)';
}

enum AuthErrorKind {
  invalidEmail,
  invalidCode,
  codeExpired,
  rateLimited,
  notSignedIn,
}

final class AuthError extends DomainError {
  const AuthError(this.kind);
  final AuthErrorKind kind;

  @override
  String toString() => 'AuthError(${kind.name})';
}

enum BiometricErrorKind { notAvailable, notEnrolled, lockedOut, cancelled }

final class BiometricError extends DomainError {
  const BiometricError(this.kind);
  final BiometricErrorKind kind;

  @override
  String toString() => 'BiometricError(${kind.name})';
}

enum ExportErrorReason { emptyRange, writeFailed, shareFailed }

final class ExportError extends DomainError {
  const ExportError(this.reason);
  final ExportErrorReason reason;

  @override
  String toString() => 'ExportError(${reason.name})';
}

final class UnknownError extends DomainError {
  const UnknownError([this.cause]);
  final Object? cause;

  @override
  String toString() => 'UnknownError($cause)';
}

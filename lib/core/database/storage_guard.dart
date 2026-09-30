import 'package:centavo/core/errors/domain_error.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:sqlite3/common.dart' show SqliteException;

/// Runs a database operation and translates low-level failures into
/// [DomainError].
Future<T> guardStorage<T>(
  Future<T> Function() body, {
  required String entity,
}) async {
  try {
    return await body();
  } on DomainError {
    rethrow;
  } on Object catch (error) {
    throw mapStorageError(error, entity: entity);
  }
}

/// Same as [guardStorage] for streams: errors are rethrown as [DomainError].
Stream<T> guardStorageStream<T>(Stream<T> stream, {required String entity}) =>
    stream.handleError((Object error, StackTrace stackTrace) {
      if (error is DomainError) throw error;
      throw mapStorageError(error, entity: entity);
    });

DomainError mapStorageError(Object error, {required String entity}) {
  // drift_flutter runs SQLite in a background isolate: errors arrive wrapped
  // in DriftRemoteException.
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  if (cause is SqliteException) {
    return switch (cause.extendedResultCode) {
      // SQLITE_CONSTRAINT_UNIQUE / SQLITE_CONSTRAINT_PRIMARYKEY
      2067 || 1555 => DuplicateError(entity),
      // SQLITE_CONSTRAINT_FOREIGNKEY
      787 => NotFoundError(entity),
      _ => StorageError(cause),
    };
  }
  return StorageError(cause);
}

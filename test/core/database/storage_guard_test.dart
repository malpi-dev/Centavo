import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/database/storage_guard.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SqliteException sqlite(int extended) =>
      SqliteException(extendedResultCode: extended, message: 'boom');

  test('unique and primary key violations become DuplicateError', () {
    expect(
      mapStorageError(sqlite(2067), entity: 'category'),
      isA<DuplicateError>().having((e) => e.entity, 'entity', 'category'),
    );
    expect(mapStorageError(sqlite(1555), entity: 'x'), isA<DuplicateError>());
  });

  test('foreign key violation becomes NotFoundError', () {
    expect(
      mapStorageError(sqlite(787), entity: 'category'),
      isA<NotFoundError>(),
    );
  });

  test('other SQLite errors become StorageError', () {
    expect(mapStorageError(sqlite(1), entity: 'x'), isA<StorageError>());
    expect(mapStorageError(StateError('x'), entity: 'x'), isA<StorageError>());
  });

  test('errors wrapped in DriftRemoteException are unwrapped', () async {
    // Provoke a real remote error through a Drift isolate.
    final isolate = await DriftIsolate.spawn(NativeDatabase.memory);
    final connection = await isolate.connect();
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO sync_state (key, value) VALUES ('a', '1')",
    );
    Object? caught;
    try {
      await db.customStatement(
        "INSERT INTO sync_state (key, value) VALUES ('a', '2')",
      );
    } on Object catch (e) {
      caught = e;
    }
    expect(caught, isA<DriftRemoteException>());
    expect(mapStorageError(caught!, entity: 'x'), isA<DuplicateError>());
  });

  test('guardStorage rethrows DomainError untouched', () {
    const error = ValidationError('name', ValidationReason.required);
    expect(
      guardStorage<void>(() async => throw error, entity: 'x'),
      throwsA(same(error)),
    );
  });

  test('guardStorage translates raw exceptions', () {
    expect(
      guardStorage<void>(() async => throw sqlite(2067), entity: 'x'),
      throwsA(isA<DuplicateError>()),
    );
  });

  test('guardStorageStream translates stream errors', () {
    final stream = guardStorageStream(
      Stream<int>.error(sqlite(787)),
      entity: 'x',
    );
    expect(stream, emitsError(isA<NotFoundError>()));
  });
}

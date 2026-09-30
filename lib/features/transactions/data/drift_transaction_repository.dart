import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/database/storage_guard.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/id_generator.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/transactions/data/transaction_row_mapper.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:centavo/features/transactions/domain/transaction_repository.dart';
import 'package:centavo/features/transactions/domain/transaction_validator.dart';
import 'package:drift/drift.dart';

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(
    this._db, {
    required this._clock,
    required this._ids,
  });

  static const _entity = 'transaction';

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  $TransactionsTable get _table => _db.transactions;

  SimpleSelectStatement<$TransactionsTable, TransactionRow> _select(
    LocalDate? from,
    LocalDate? toExclusive,
  ) => _db.select(_table)
    ..where((t) {
      var filter = t.deletedAt.isNull();
      if (from != null) {
        filter = filter & t.occurredOn.isBiggerOrEqualValue(from.toIso());
      }
      if (toExclusive != null) {
        filter = filter & t.occurredOn.isSmallerThanValue(toExclusive.toIso());
      }
      return filter;
    })
    ..orderBy([
      (t) => OrderingTerm.desc(t.occurredOn),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);

  @override
  Stream<List<MoneyTransaction>> watchBetween(
    LocalDate from,
    LocalDate toExclusive,
  ) => guardStorageStream(
    _select(
      from,
      toExclusive,
    ).watch().map((rows) => rows.map((r) => r.toDomain()).toList()),
    entity: _entity,
  );

  @override
  Future<List<MoneyTransaction>> getBetween(
    LocalDate? from,
    LocalDate? toExclusive,
  ) => guardStorage(() async {
    final rows = await _select(from, toExclusive).get();
    return rows.map((r) => r.toDomain()).toList();
  }, entity: _entity);

  Future<TransactionRow?> _findRow(String id) => (_db.select(
    _table,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  @override
  Future<MoneyTransaction?> findById(String id) => guardStorage(
    () async => (await _findRow(id))?.toDomain(),
    entity: _entity,
  );

  Future<void> _assertCategory(String categoryId, TransactionType type) async {
    final category =
        await (_db.select(_db.categories)
              ..where((c) => c.id.equals(categoryId) & c.deletedAt.isNull()))
            .getSingleOrNull();
    if (category == null) throw NotFoundError('category', categoryId);
    if (category.type != type) throw const CategoryTypeMismatchError();
  }

  @override
  Future<MoneyTransaction> create(TransactionDraft draft) =>
      guardStorage(() async {
        assertValidDraft(draft);
        await _assertCategory(draft.categoryId, draft.type);
        final now = _clock.nowUtc();
        final transaction = MoneyTransaction(
          id: _ids.newId(),
          type: draft.type,
          amountMinor: draft.amountMinor,
          categoryId: draft.categoryId,
          occurredOn: draft.occurredOn,
          note: normalizeNote(draft.note),
          createdAt: now,
          updatedAt: now,
        );
        await _db.into(_table).insert(transaction.toCompanion());
        return transaction;
      }, entity: _entity);

  @override
  Future<MoneyTransaction> update(MoneyTransaction transaction) =>
      guardStorage(() async {
        final current = await _findRow(transaction.id);
        if (current == null) throw NotFoundError(_entity, transaction.id);
        assertValidDraft(
          TransactionDraft(
            type: transaction.type,
            amountMinor: transaction.amountMinor,
            categoryId: transaction.categoryId,
            occurredOn: transaction.occurredOn,
            note: transaction.note,
          ),
        );
        await _assertCategory(transaction.categoryId, transaction.type);
        final updated = transaction.copyWith(
          note: normalizeNote(transaction.note),
          createdAt: current.createdAt.toUtc(),
          updatedAt: _clock.nowUtc(),
          deletedAt: null,
        );
        await (_db.update(_table)..where((t) => t.id.equals(updated.id))).write(
          TransactionsCompanion(
            type: Value(updated.type),
            amountMinor: Value(updated.amountMinor),
            categoryId: Value(updated.categoryId),
            occurredOn: Value(updated.occurredOn),
            note: Value(updated.note),
            updatedAt: Value(updated.updatedAt),
          ),
        );
        return updated;
      }, entity: _entity);

  @override
  Future<void> softDelete(String id) => guardStorage(() async {
    final now = _clock.nowUtc();
    await (_db.update(_table)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }, entity: _entity);

  @override
  Future<void> restore(String id) => guardStorage(() async {
    await (_db.update(_table)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(_clock.nowUtc()),
      ),
    );
  }, entity: _entity);

  @override
  Future<int> countByCategory(String categoryId) => guardStorage(() async {
    final count = _table.id.count();
    final query = _db.selectOnly(_table)
      ..addColumns([count])
      ..where(_table.categoryId.equals(categoryId) & _table.deletedAt.isNull());
    return (await query.getSingle()).read(count) ?? 0;
  }, entity: _entity);

  @override
  Future<List<MoneyTransaction>> changedSince(DateTime? sinceUtc) =>
      guardStorage(() async {
        final query = _db.select(_table)
          ..orderBy([
            (t) => OrderingTerm.asc(t.updatedAt),
            (t) => OrderingTerm.asc(t.id),
          ]);
        if (sinceUtc != null) {
          query.where((t) => t.updatedAt.isBiggerThanValue(sinceUtc));
        }
        return (await query.get()).map((r) => r.toDomain()).toList();
      }, entity: _entity);

  @override
  Future<void> mergeFromBackup(List<MoneyTransaction> incoming) =>
      guardStorage(() async {
        for (final row in incoming) {
          final local = await (_db.select(
            _table,
          )..where((t) => t.id.equals(row.id))).getSingleOrNull();
          if (local != null && !local.updatedAt.isBefore(row.updatedAt)) {
            continue;
          }
          await _db.into(_table).insertOnConflictUpdate(row.toCompanion());
        }
      }, entity: _entity);
}

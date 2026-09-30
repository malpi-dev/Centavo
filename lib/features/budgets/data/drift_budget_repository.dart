import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/database/storage_guard.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/id_generator.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/budgets/data/budget_row_mapper.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/budgets/domain/budget_repository.dart';
import 'package:drift/drift.dart';

class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(
    this._db, {
    required this._clock,
    required this._ids,
  });

  static const _entity = 'budget';

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  $BudgetsTable get _table => _db.budgets;

  SimpleSelectStatement<$BudgetsTable, BudgetRow> _selectMonth(
    YearMonth month,
  ) => _db.select(_table)
    ..where(
      (b) => b.month.equals(month.toFirstDayIso()) & b.deletedAt.isNull(),
    );

  @override
  Stream<List<Budget>> watchMonth(YearMonth month) => guardStorageStream(
    _selectMonth(
      month,
    ).watch().map((rows) => rows.map((r) => r.toDomain()).toList()),
    entity: _entity,
  );

  @override
  Future<List<Budget>> getMonth(YearMonth month) => guardStorage(() async {
    final rows = await _selectMonth(month).get();
    return rows.map((r) => r.toDomain()).toList();
  }, entity: _entity);

  Future<BudgetRow?> _findRow(String categoryId, YearMonth month) =>
      (_selectMonth(
        month,
      )..where((b) => b.categoryId.equals(categoryId))).getSingleOrNull();

  @override
  Future<Budget?> findActive(String categoryId, YearMonth month) =>
      guardStorage(
        () async => (await _findRow(categoryId, month))?.toDomain(),
        entity: _entity,
      );

  @override
  Future<Budget> setLimit({
    required String categoryId,
    required YearMonth month,
    required int limitMinor,
  }) => guardStorage(() async {
    if (limitMinor <= 0) {
      throw const ValidationError('limit', ValidationReason.mustBePositive);
    }
    return _db.transaction(() async {
      final category =
          await (_db.select(_db.categories)
                ..where((c) => c.id.equals(categoryId) & c.deletedAt.isNull()))
              .getSingleOrNull();
      if (category == null) throw NotFoundError('category', categoryId);
      if (category.type != TransactionType.expense) {
        throw const CategoryTypeMismatchError();
      }
      final now = _clock.nowUtc();
      final existing = await _findRow(categoryId, month);
      if (existing != null) {
        await (_db.update(
          _table,
        )..where((b) => b.id.equals(existing.id))).write(
          BudgetsCompanion(
            limitMinor: Value(limitMinor),
            updatedAt: Value(now),
          ),
        );
        return existing.toDomain().copyWith(
          limitMinor: limitMinor,
          updatedAt: now,
        );
      }
      final budget = Budget(
        id: _ids.newId(),
        categoryId: categoryId,
        month: month,
        limitMinor: limitMinor,
        createdAt: now,
        updatedAt: now,
      );
      await _db.into(_table).insert(budget.toCompanion());
      return budget;
    });
  }, entity: _entity);

  Future<void> _tombstone(Expression<bool> Function($BudgetsTable b) where) =>
      guardStorage(() async {
        final now = _clock.nowUtc();
        await (_db.update(
          _table,
        )..where((b) => where(b) & b.deletedAt.isNull())).write(
          BudgetsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
      }, entity: _entity);

  @override
  Future<void> softDelete(String id) => _tombstone((b) => b.id.equals(id));

  @override
  Future<void> softDeleteByCategory(String categoryId) =>
      _tombstone((b) => b.categoryId.equals(categoryId));
}

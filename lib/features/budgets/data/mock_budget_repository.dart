import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/id_generator.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/budgets/domain/budget_repository.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';

/// In-memory [BudgetRepository] with the same rules as the Drift one.
class MockBudgetRepository implements BudgetRepository {
  MockBudgetRepository(
    this._store, {
    required this._clock,
    required this._ids,
  });

  final MockDataStore _store;
  final Clock _clock;
  final IdGenerator _ids;

  List<Budget> _month(YearMonth month) => List.unmodifiable(
    _store.budgets.where((b) => b.month == month && b.deletedAt == null),
  );

  @override
  Stream<List<Budget>> watchMonth(YearMonth month) =>
      _store.watch(MockTable.budgets, () => _month(month));

  @override
  Future<List<Budget>> getMonth(YearMonth month) async => _month(month);

  @override
  Future<Budget?> findActive(String categoryId, YearMonth month) async {
    for (final b in _month(month)) {
      if (b.categoryId == categoryId) return b;
    }
    return null;
  }

  @override
  Future<Budget> setLimit({
    required String categoryId,
    required YearMonth month,
    required int limitMinor,
  }) async {
    if (limitMinor <= 0) {
      throw const ValidationError('limit', ValidationReason.mustBePositive);
    }
    final matches = _store.categories.where(
      (c) => c.id == categoryId && !c.isDeleted,
    );
    if (matches.isEmpty) throw NotFoundError('category', categoryId);
    if (matches.first.type != TransactionType.expense) {
      throw const CategoryTypeMismatchError();
    }
    final now = _clock.nowUtc();
    final existing = await findActive(categoryId, month);
    final Budget saved;
    if (existing != null) {
      saved = existing.copyWith(limitMinor: limitMinor, updatedAt: now);
      _store.budgets[_store.budgets.indexWhere((b) => b.id == existing.id)] =
          saved;
    } else {
      saved = Budget(
        id: _ids.newId(),
        categoryId: categoryId,
        month: month,
        limitMinor: limitMinor,
        createdAt: now,
        updatedAt: now,
      );
      _store.budgets.add(saved);
    }
    _store.notify(MockTable.budgets);
    return saved;
  }

  void _tombstone(bool Function(Budget b) where) {
    final now = _clock.nowUtc();
    var changed = false;
    for (var i = 0; i < _store.budgets.length; i++) {
      final b = _store.budgets[i];
      if (b.deletedAt == null && where(b)) {
        _store.budgets[i] = b.copyWith(deletedAt: now, updatedAt: now);
        changed = true;
      }
    }
    if (changed) _store.notify(MockTable.budgets);
  }

  @override
  Future<void> softDelete(String id) async => _tombstone((b) => b.id == id);

  @override
  Future<void> softDeleteByCategory(String categoryId) async =>
      _tombstone((b) => b.categoryId == categoryId);

  @override
  Future<List<Budget>> changedSince(DateTime? sinceUtc) async {
    final rows =
        _store.budgets
            .where((b) => sinceUtc == null || b.updatedAt.isAfter(sinceUtc))
            .toList()
          ..sort((a, b) {
            final byTime = a.updatedAt.compareTo(b.updatedAt);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
    return List.unmodifiable(rows);
  }

  @override
  Future<void> mergeFromBackup(List<Budget> incoming) async {
    for (final row in incoming) {
      final index = _store.budgets.indexWhere((b) => b.id == row.id);
      if (index >= 0 &&
          !_store.budgets[index].updatedAt.isBefore(row.updatedAt)) {
        continue;
      }
      var toWrite = row;
      if (row.deletedAt == null) {
        final rivalIndex = _store.budgets.indexWhere(
          (b) =>
              b.id != row.id &&
              b.deletedAt == null &&
              b.categoryId == row.categoryId &&
              b.month == row.month,
        );
        if (rivalIndex >= 0) {
          final now = _clock.nowUtc();
          final rival = _store.budgets[rivalIndex];
          if (rival.updatedAt.isBefore(row.updatedAt)) {
            _store.budgets[rivalIndex] = rival.copyWith(
              deletedAt: now,
              updatedAt: now,
            );
          } else {
            toWrite = row.copyWith(deletedAt: now, updatedAt: now);
          }
        }
      }
      final target = _store.budgets.indexWhere((b) => b.id == row.id);
      if (target >= 0) {
        _store.budgets[target] = toWrite;
      } else {
        _store.budgets.add(toWrite);
      }
    }
    _store.notify(MockTable.budgets);
  }
}

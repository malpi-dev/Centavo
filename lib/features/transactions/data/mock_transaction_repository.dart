import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/id_generator.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:centavo/features/transactions/domain/transaction_repository.dart';
import 'package:centavo/features/transactions/domain/transaction_validator.dart';

/// In-memory [TransactionRepository] with the same rules as the Drift one.
class MockTransactionRepository implements TransactionRepository {
  MockTransactionRepository(
    this._store, {
    required this._clock,
    required this._ids,
  });

  static const _entity = 'transaction';

  final MockDataStore _store;
  final Clock _clock;
  final IdGenerator _ids;

  List<MoneyTransaction> _between(LocalDate? from, LocalDate? toExclusive) {
    final list =
        // Reversed so that ties keep the newest insertion first, like Drift.
        _store.transactions.reversed
            .where(
              (t) =>
                  t.deletedAt == null &&
                  (from == null || t.occurredOn.compareTo(from) >= 0) &&
                  (toExclusive == null ||
                      t.occurredOn.compareTo(toExclusive) < 0),
            )
            .toList()
          ..sort((a, b) {
            final byDay = b.occurredOn.compareTo(a.occurredOn);
            return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
          });
    return List.unmodifiable(list);
  }

  int _indexOf(String id) => _store.transactions.indexWhere((t) => t.id == id);

  void _put(int index, MoneyTransaction transaction) {
    _store.transactions[index] = transaction;
    _store.notify(MockTable.transactions);
  }

  void _assertCategory(String categoryId, TransactionType type) {
    final matches = _store.categories.where(
      (c) => c.id == categoryId && !c.isDeleted,
    );
    if (matches.isEmpty) throw NotFoundError('category', categoryId);
    if (matches.first.type != type) throw const CategoryTypeMismatchError();
  }

  @override
  Stream<List<MoneyTransaction>> watchBetween(
    LocalDate from,
    LocalDate toExclusive,
  ) => _store.watch(MockTable.transactions, () => _between(from, toExclusive));

  @override
  Future<List<MoneyTransaction>> getBetween(
    LocalDate? from,
    LocalDate? toExclusive,
  ) async => _between(from, toExclusive);

  @override
  Future<MoneyTransaction?> findById(String id) async {
    final index = _indexOf(id);
    if (index < 0 || _store.transactions[index].deletedAt != null) return null;
    return _store.transactions[index];
  }

  @override
  Future<MoneyTransaction> create(TransactionDraft draft) async {
    assertValidDraft(draft);
    _assertCategory(draft.categoryId, draft.type);
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
    _store.transactions.add(transaction);
    _store.notify(MockTable.transactions);
    return transaction;
  }

  @override
  Future<MoneyTransaction> update(MoneyTransaction transaction) async {
    final index = _indexOf(transaction.id);
    if (index < 0 || _store.transactions[index].deletedAt != null) {
      throw NotFoundError(_entity, transaction.id);
    }
    final current = _store.transactions[index];
    assertValidDraft(
      TransactionDraft(
        type: transaction.type,
        amountMinor: transaction.amountMinor,
        categoryId: transaction.categoryId,
        occurredOn: transaction.occurredOn,
        note: transaction.note,
      ),
    );
    _assertCategory(transaction.categoryId, transaction.type);
    final updated = transaction.copyWith(
      note: normalizeNote(transaction.note),
      createdAt: current.createdAt,
      updatedAt: _clock.nowUtc(),
      deletedAt: null,
    );
    _put(index, updated);
    return updated;
  }

  @override
  Future<void> softDelete(String id) async {
    final index = _indexOf(id);
    if (index < 0) return;
    final now = _clock.nowUtc();
    _put(
      index,
      _store.transactions[index].copyWith(deletedAt: now, updatedAt: now),
    );
  }

  @override
  Future<void> restore(String id) async {
    final index = _indexOf(id);
    if (index < 0) return;
    _put(
      index,
      _store.transactions[index].copyWith(
        deletedAt: null,
        updatedAt: _clock.nowUtc(),
      ),
    );
  }

  @override
  Future<int> countByCategory(String categoryId) async => _store.transactions
      .where((t) => t.categoryId == categoryId && t.deletedAt == null)
      .length;
}

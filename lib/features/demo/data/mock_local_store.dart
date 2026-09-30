import 'package:centavo/core/domain/local_store.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';

class MockLocalStore implements LocalStore {
  MockLocalStore(this._store);

  final MockDataStore _store;

  void _notifyAll() => MockTable.values.forEach(_store.notify);

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    final categories = [..._store.categories];
    final transactions = [..._store.transactions];
    final budgets = [..._store.budgets];
    try {
      return await action();
    } catch (_) {
      _store.categories
        ..clear()
        ..addAll(categories);
      _store.transactions
        ..clear()
        ..addAll(transactions);
      _store.budgets
        ..clear()
        ..addAll(budgets);
      _notifyAll();
      rethrow;
    }
  }

  @override
  Future<void> eraseAll() async {
    _store.categories.clear();
    _store.transactions.clear();
    _store.budgets.clear();
    _store.syncState.clear();
    _notifyAll();
  }
}

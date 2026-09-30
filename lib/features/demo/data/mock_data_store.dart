import 'dart:async';

import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';

enum MockTable { categories, transactions, budgets }

/// In-memory tables shared by all mock repositories, with change
/// notifications that mimic Drift streams.
class MockDataStore {
  MockDataStore({
    List<Category>? categories,
    List<MoneyTransaction>? transactions,
    List<Budget>? budgets,
  }) : categories = [...?categories],
       transactions = [...?transactions],
       budgets = [...?budgets];

  final List<Category> categories;
  final List<MoneyTransaction> transactions;
  final List<Budget> budgets;
  final Map<String, String> syncState = {};
  final _changes = StreamController<MockTable>.broadcast();

  void notify(MockTable table) {
    if (!_changes.isClosed) _changes.add(table);
  }

  /// Emits the current value on listen and again after every change of
  /// [table].
  Stream<T> watch<T>(MockTable table, T Function() read) {
    late StreamController<T> controller;
    StreamSubscription<MockTable>? subscription;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        subscription = _changes.stream
            .where((t) => t == table)
            .listen((_) => controller.add(read()));
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  Future<void> dispose() => _changes.close();
}

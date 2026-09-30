import 'dart:async';

import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/backup/domain/backup_repository.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';

/// In-memory "cloud" for the demo and tests. Rows are kept by id and upserts
/// are last-write-wins, like the `keep_newest` trigger in Postgres.
class MockBackupRepository implements BackupRepository {
  MockBackupRepository({this.latency = const Duration(milliseconds: 400)});

  final Duration latency;
  BackupProfile? _profile;
  final _categories = <String, Category>{};
  final _budgets = <String, Budget>{};
  final _transactions = <String, MoneyTransaction>{};
  DomainError? _nextError;

  /// The next call throws [error] once.
  // ignore: use_setters_to_change_properties, reads better in tests
  void failNextWith(DomainError error) => _nextError = error;

  /// Pre-populates the cloud (tests).
  void seed({
    BackupProfile? profile,
    List<Category> categories = const [],
    List<Budget> budgets = const [],
    List<MoneyTransaction> transactions = const [],
  }) {
    _profile = profile;
    for (final c in categories) {
      _categories[c.id] = c;
    }
    for (final b in budgets) {
      _budgets[b.id] = b;
    }
    for (final t in transactions) {
      _transactions[t.id] = t;
    }
  }

  int get categoryCount => _categories.length;
  int get budgetCount => _budgets.length;
  int get transactionCount => _transactions.length;

  Future<void> _call() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final error = _nextError;
    if (error != null) {
      _nextError = null;
      throw error;
    }
  }

  @override
  Future<BackupProfile> ensureProfile(String currencyCode) async {
    await _call();
    return _profile ??= BackupProfile(currencyCode: currencyCode);
  }

  @override
  Future<void> updateCurrency(String currencyCode) async {
    await _call();
    _profile = BackupProfile(currencyCode: currencyCode);
  }

  @override
  Future<BackupProfile?> fetchProfile() async {
    await _call();
    return _profile;
  }

  @override
  Future<void> upsertCategories(List<Category> rows) async {
    await _call();
    for (final r in rows) {
      final current = _categories[r.id];
      if (current == null || !current.updatedAt.isAfter(r.updatedAt)) {
        _categories[r.id] = r;
      }
    }
  }

  @override
  Future<void> upsertBudgets(List<Budget> rows) async {
    await _call();
    for (final r in rows) {
      final current = _budgets[r.id];
      if (current == null || !current.updatedAt.isAfter(r.updatedAt)) {
        _budgets[r.id] = r;
      }
    }
  }

  @override
  Future<void> upsertTransactions(List<MoneyTransaction> rows) async {
    await _call();
    for (final r in rows) {
      final current = _transactions[r.id];
      if (current == null || !current.updatedAt.isAfter(r.updatedAt)) {
        _transactions[r.id] = r;
      }
    }
  }

  @override
  Future<List<Category>> fetchCategories() async {
    await _call();
    return _categories.values.toList();
  }

  @override
  Future<List<Budget>> fetchBudgets() async {
    await _call();
    return _budgets.values.toList();
  }

  @override
  Future<List<MoneyTransaction>> fetchTransactions() async {
    await _call();
    return _transactions.values.toList();
  }

  @override
  Future<void> deleteAll() async {
    await _call();
    _transactions.clear();
    _budgets.clear();
    _categories.clear();
  }
}

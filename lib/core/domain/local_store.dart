/// Operations that span several local repositories.
abstract interface class LocalStore {
  /// Runs [action] atomically (a Drift transaction in production; a plain call
  /// in mocks).
  Future<T> runInTransaction<T>(Future<T> Function() action);

  /// Deletes every local row (categories, transactions, budgets, sync state).
  /// Used by "Erase all local data".
  Future<void> eraseAll();
}

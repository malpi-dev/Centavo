import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/categories/domain/category.dart';

abstract interface class CategoryRepository {
  /// Non-deleted categories (active and archived) ordered by type (expense
  /// first), then name case-insensitively.
  Stream<List<Category>> watchAll();

  Future<List<Category>> getAll();

  /// Null when missing or deleted.
  Future<Category?> findById(String id);

  /// Validates (ValidationError), normalizes the name and enforces uniqueness
  /// among ACTIVE categories by (lower(name), type) ->
  /// DuplicateError('category').
  Future<Category> create({
    required String name,
    required TransactionType type,
    required String icon,
    required int color,
  });

  /// Updates name, icon and color. Changing type -> ValidationError('type',
  /// notAllowed). Same uniqueness rule. Missing/deleted ->
  /// NotFoundError('category', id).
  Future<Category> update(Category category);

  Future<void> archive(String id);

  /// DuplicateError if an active category with the same name and type exists.
  Future<void> unarchive(String id);

  /// Tombstone. No checks here: DeleteOrArchiveCategory decides whether
  /// deleting is allowed.
  Future<void> softDelete(String id);

  /// Inserts categories keeping their ids and timestamps. Ids that already
  /// exist (even deleted) are skipped.
  Future<void> insertIfAbsent(List<Category> categories);

  /// Rows with updatedAt > [sinceUtc] (all rows when null), INCLUDING
  /// archived and deleted ones, ordered by updatedAt.
  Future<List<Category>> changedSince(DateTime? sinceUtc);

  /// Merges rows downloaded from the backup (last-write-wins by id). Never
  /// deletes local rows that are not in [incoming].
  /// An active incoming category whose (name, type) clashes with ANOTHER
  /// active local one is saved as `"<name> 2"` (then 3, ...).
  Future<void> mergeFromBackup(List<Category> incoming);
}

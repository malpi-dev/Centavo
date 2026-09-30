import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/database/storage_guard.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/id_generator.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/categories/data/category_row_mapper.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/categories/domain/category_validator.dart';
import 'package:drift/drift.dart';

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(
    this._db, {
    required this._clock,
    required this._ids,
  });

  static const _entity = 'category';

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  $CategoriesTable get _table => _db.categories;

  SimpleSelectStatement<$CategoriesTable, CategoryRow> _selectAll() =>
      _db.select(_table)
        ..where((c) => c.deletedAt.isNull())
        ..orderBy([
          (c) => OrderingTerm.asc(c.type),
          (c) => OrderingTerm.asc(c.name.lower()),
        ]);

  @override
  Stream<List<Category>> watchAll() => guardStorageStream(
    _selectAll().watch().map((rows) => rows.map((r) => r.toDomain()).toList()),
    entity: _entity,
  );

  @override
  Future<List<Category>> getAll() => guardStorage(() async {
    final rows = await _selectAll().get();
    return rows.map((r) => r.toDomain()).toList();
  }, entity: _entity);

  @override
  Future<Category?> findById(String id) => guardStorage(
    () async => (await _findRow(id))?.toDomain(),
    entity: _entity,
  );

  Future<CategoryRow?> _findRow(String id) => (_db.select(
    _table,
  )..where((c) => c.id.equals(id) & c.deletedAt.isNull())).getSingleOrNull();

  Future<bool> _activeDuplicateExists(
    String name,
    TransactionType type, {
    String? excludingId,
  }) async {
    final query = _db.select(_table)
      ..where(
        (c) =>
            c.name.lower().equals(name.toLowerCase()) &
            c.type.equalsValue(type) &
            c.archivedAt.isNull() &
            c.deletedAt.isNull(),
      );
    if (excludingId != null) query.where((c) => c.id.equals(excludingId).not());
    return (await query.get()).isNotEmpty;
  }

  void _validate(String name, String icon, int color) {
    final errors = validateCategoryForm(name: name, icon: icon, color: color);
    if (errors.isNotEmpty) {
      final first = errors.entries.first;
      throw ValidationError(first.key, first.value);
    }
  }

  @override
  Future<Category> create({
    required String name,
    required TransactionType type,
    required String icon,
    required int color,
  }) => guardStorage(() async {
    _validate(name, icon, color);
    final normalized = normalizeCategoryName(name);
    if (await _activeDuplicateExists(normalized, type)) {
      throw const DuplicateError(_entity);
    }
    final now = _clock.nowUtc();
    final category = Category(
      id: _ids.newId(),
      name: normalized,
      type: type,
      icon: icon,
      color: color,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_table).insert(category.toCompanion());
    return category;
  }, entity: _entity);

  @override
  Future<Category> update(Category category) => guardStorage(() async {
    final current = await _findRow(category.id);
    if (current == null) throw NotFoundError(_entity, category.id);
    if (current.type != category.type) {
      throw const ValidationError('type', ValidationReason.notAllowed);
    }
    _validate(category.name, category.icon, category.color);
    final normalized = normalizeCategoryName(category.name);
    if (current.archivedAt == null &&
        await _activeDuplicateExists(
          normalized,
          current.type,
          excludingId: current.id,
        )) {
      throw const DuplicateError(_entity);
    }
    final now = _clock.nowUtc();
    await (_db.update(_table)..where((c) => c.id.equals(current.id))).write(
      CategoriesCompanion(
        name: Value(normalized),
        icon: Value(category.icon),
        color: Value(category.color),
        updatedAt: Value(now),
      ),
    );
    return current.toDomain().copyWith(
      name: normalized,
      icon: category.icon,
      color: category.color,
      updatedAt: now,
    );
  }, entity: _entity);

  Future<CategoryRow> _requireRow(String id) async {
    final row = await _findRow(id);
    if (row == null) throw NotFoundError(_entity, id);
    return row;
  }

  Future<void> _write(String id, CategoriesCompanion changes) async {
    await (_db.update(_table)..where((c) => c.id.equals(id))).write(changes);
  }

  @override
  Future<void> archive(String id) => guardStorage(() async {
    await _requireRow(id);
    final now = _clock.nowUtc();
    await _write(
      id,
      CategoriesCompanion(archivedAt: Value(now), updatedAt: Value(now)),
    );
  }, entity: _entity);

  @override
  Future<void> unarchive(String id) => guardStorage(() async {
    final row = await _requireRow(id);
    if (await _activeDuplicateExists(row.name, row.type, excludingId: id)) {
      throw const DuplicateError(_entity);
    }
    await _write(
      id,
      CategoriesCompanion(
        archivedAt: const Value(null),
        updatedAt: Value(_clock.nowUtc()),
      ),
    );
  }, entity: _entity);

  @override
  Future<void> softDelete(String id) => guardStorage(() async {
    await _requireRow(id);
    final now = _clock.nowUtc();
    await _write(
      id,
      CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }, entity: _entity);

  @override
  Future<void> insertIfAbsent(List<Category> categories) =>
      guardStorage(() async {
        await _db.batch((batch) {
          batch.insertAll(
            _table,
            categories.map((c) => c.toCompanion()),
            mode: InsertMode.insertOrIgnore,
          );
        });
      }, entity: _entity);

  @override
  Future<List<Category>> changedSince(DateTime? sinceUtc) =>
      guardStorage(() async {
        final query = _db.select(_table)
          ..orderBy([
            (c) => OrderingTerm.asc(c.updatedAt),
            (c) => OrderingTerm.asc(c.id),
          ]);
        if (sinceUtc != null) {
          query.where((c) => c.updatedAt.isBiggerThanValue(sinceUtc));
        }
        return (await query.get()).map((r) => r.toDomain()).toList();
      }, entity: _entity);

  @override
  Future<void> mergeFromBackup(List<Category> incoming) =>
      guardStorage(() async {
        for (final row in incoming) {
          final local = await (_db.select(
            _table,
          )..where((c) => c.id.equals(row.id))).getSingleOrNull();
          if (local != null && !local.updatedAt.isBefore(row.updatedAt)) {
            continue;
          }
          var toWrite = row;
          if (row.isActive) {
            final others =
                await (_db.select(_table)..where(
                      (c) =>
                          c.type.equalsValue(row.type) &
                          c.archivedAt.isNull() &
                          c.deletedAt.isNull() &
                          c.id.equals(row.id).not(),
                    ))
                    .get();
            final taken = {for (final c in others) c.name.toLowerCase()};
            toWrite = row.copyWith(
              name: disambiguateCategoryName(
                row.name,
                (candidate) => taken.contains(candidate.toLowerCase()),
              ),
            );
          }
          await _db.into(_table).insertOnConflictUpdate(toWrite.toCompanion());
        }
      }, entity: _entity);
}

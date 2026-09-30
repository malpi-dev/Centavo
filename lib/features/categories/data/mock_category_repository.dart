import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/id_generator.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/categories/domain/category_validator.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';

/// In-memory [CategoryRepository] with the same rules as the Drift one.
class MockCategoryRepository implements CategoryRepository {
  MockCategoryRepository(
    this._store, {
    required this._clock,
    required this._ids,
  });

  static const _entity = 'category';

  final MockDataStore _store;
  final Clock _clock;
  final IdGenerator _ids;

  List<Category> _all() {
    final list = _store.categories.where((c) => !c.isDeleted).toList()
      ..sort((a, b) {
        final byType = a.type.name.compareTo(b.type.name);
        if (byType != 0) return byType;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return List.unmodifiable(list);
  }

  int _indexOf(String id) => _store.categories.indexWhere((c) => c.id == id);

  Category _require(String id) {
    final index = _indexOf(id);
    if (index < 0 || _store.categories[index].isDeleted) {
      throw NotFoundError(_entity, id);
    }
    return _store.categories[index];
  }

  void _put(Category category) {
    _store.categories[_indexOf(category.id)] = category;
    _store.notify(MockTable.categories);
  }

  bool _activeDuplicateExists(
    String name,
    TransactionType type, {
    String? excludingId,
  }) => _store.categories.any(
    (c) =>
        c.id != excludingId &&
        c.name.toLowerCase() == name.toLowerCase() &&
        c.type == type &&
        c.isActive,
  );

  void _validate(String name, String icon, int color) {
    final errors = validateCategoryForm(name: name, icon: icon, color: color);
    if (errors.isNotEmpty) {
      final first = errors.entries.first;
      throw ValidationError(first.key, first.value);
    }
  }

  @override
  Stream<List<Category>> watchAll() => _store.watch(MockTable.categories, _all);

  @override
  Future<List<Category>> getAll() async => _all();

  @override
  Future<Category?> findById(String id) async {
    final index = _indexOf(id);
    if (index < 0 || _store.categories[index].isDeleted) return null;
    return _store.categories[index];
  }

  @override
  Future<Category> create({
    required String name,
    required TransactionType type,
    required String icon,
    required int color,
  }) async {
    _validate(name, icon, color);
    final normalized = normalizeCategoryName(name);
    if (_activeDuplicateExists(normalized, type)) {
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
    _store.categories.add(category);
    _store.notify(MockTable.categories);
    return category;
  }

  @override
  Future<Category> update(Category category) async {
    final current = _require(category.id);
    if (current.type != category.type) {
      throw const ValidationError('type', ValidationReason.notAllowed);
    }
    _validate(category.name, category.icon, category.color);
    final normalized = normalizeCategoryName(category.name);
    if (current.archivedAt == null &&
        _activeDuplicateExists(
          normalized,
          current.type,
          excludingId: current.id,
        )) {
      throw const DuplicateError(_entity);
    }
    final updated = current.copyWith(
      name: normalized,
      icon: category.icon,
      color: category.color,
      updatedAt: _clock.nowUtc(),
    );
    _put(updated);
    return updated;
  }

  @override
  Future<void> archive(String id) async {
    final now = _clock.nowUtc();
    _put(_require(id).copyWith(archivedAt: now, updatedAt: now));
  }

  @override
  Future<void> unarchive(String id) async {
    final current = _require(id);
    if (_activeDuplicateExists(
      current.name,
      current.type,
      excludingId: id,
    )) {
      throw const DuplicateError(_entity);
    }
    _put(current.copyWith(archivedAt: null, updatedAt: _clock.nowUtc()));
  }

  @override
  Future<void> softDelete(String id) async {
    final now = _clock.nowUtc();
    _put(_require(id).copyWith(deletedAt: now, updatedAt: now));
  }

  @override
  Future<void> insertIfAbsent(List<Category> categories) async {
    var changed = false;
    for (final category in categories) {
      if (_indexOf(category.id) >= 0) continue;
      _store.categories.add(category);
      changed = true;
    }
    if (changed) _store.notify(MockTable.categories);
  }

  @override
  Future<List<Category>> changedSince(DateTime? sinceUtc) async {
    final rows =
        _store.categories
            .where((c) => sinceUtc == null || c.updatedAt.isAfter(sinceUtc))
            .toList()
          ..sort((a, b) {
            final byTime = a.updatedAt.compareTo(b.updatedAt);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
    return List.unmodifiable(rows);
  }

  @override
  Future<void> mergeFromBackup(List<Category> incoming) async {
    for (final row in incoming) {
      final index = _indexOf(row.id);
      if (index >= 0 &&
          !_store.categories[index].updatedAt.isBefore(row.updatedAt)) {
        continue;
      }
      var toWrite = row;
      if (row.isActive) {
        final taken = {
          for (final c in _store.categories)
            if (c.id != row.id && c.type == row.type && c.isActive)
              c.name.toLowerCase(),
        };
        toWrite = row.copyWith(
          name: disambiguateCategoryName(
            row.name,
            (candidate) => taken.contains(candidate.toLowerCase()),
          ),
        );
      }
      if (index >= 0) {
        _store.categories[index] = toWrite;
      } else {
        _store.categories.add(toWrite);
      }
    }
    _store.notify(MockTable.categories);
  }
}

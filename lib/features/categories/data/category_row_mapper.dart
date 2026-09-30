import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:drift/drift.dart';

extension CategoryRowX on CategoryRow {
  Category toDomain() => Category(
    id: id,
    name: name,
    type: type,
    icon: icon,
    color: color,
    isDefault: isDefault,
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    archivedAt: archivedAt?.toUtc(),
    deletedAt: deletedAt?.toUtc(),
  );
}

extension CategoryToCompanion on Category {
  CategoriesCompanion toCompanion() => CategoriesCompanion.insert(
    id: id,
    name: name,
    type: type,
    icon: icon,
    color: color,
    isDefault: Value(isDefault),
    archivedAt: Value(archivedAt?.toUtc()),
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    deletedAt: Value(deletedAt?.toUtc()),
  );
}

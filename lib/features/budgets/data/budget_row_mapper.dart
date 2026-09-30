import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:drift/drift.dart';

extension BudgetRowX on BudgetRow {
  Budget toDomain() => Budget(
    id: id,
    categoryId: categoryId,
    month: month,
    limitMinor: limitMinor,
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    deletedAt: deletedAt?.toUtc(),
  );
}

extension BudgetToCompanion on Budget {
  BudgetsCompanion toCompanion() => BudgetsCompanion.insert(
    id: id,
    categoryId: categoryId,
    month: month,
    limitMinor: limitMinor,
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    deletedAt: Value(deletedAt?.toUtc()),
  );
}

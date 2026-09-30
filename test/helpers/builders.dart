import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';

final _t0 = DateTime.utc(2026);

Category aCategory({
  String id = 'cat-1',
  String name = 'Food',
  TransactionType type = TransactionType.expense,
  String icon = 'food',
  int color = 0xFFE65100,
  bool isDefault = false,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? archivedAt,
  DateTime? deletedAt,
}) => Category(
  id: id,
  name: name,
  type: type,
  icon: icon,
  color: color,
  isDefault: isDefault,
  createdAt: createdAt ?? _t0,
  updatedAt: updatedAt ?? _t0,
  archivedAt: archivedAt,
  deletedAt: deletedAt,
);

MoneyTransaction aTransaction({
  String id = 'tx-1',
  TransactionType type = TransactionType.expense,
  int amountMinor = 1000,
  String categoryId = 'cat-1',
  LocalDate? occurredOn,
  String? note,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) => MoneyTransaction(
  id: id,
  type: type,
  amountMinor: amountMinor,
  categoryId: categoryId,
  occurredOn: occurredOn ?? LocalDate(2026, 10, 5),
  note: note,
  createdAt: createdAt ?? _t0,
  updatedAt: updatedAt ?? _t0,
  deletedAt: deletedAt,
);

Budget aBudget({
  String id = 'bud-1',
  String categoryId = 'cat-1',
  YearMonth month = const YearMonth(2026, 10),
  int limitMinor = 10000,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) => Budget(
  id: id,
  categoryId: categoryId,
  month: month,
  limitMinor: limitMinor,
  createdAt: createdAt ?? _t0,
  updatedAt: updatedAt ?? _t0,
  deletedAt: deletedAt,
);

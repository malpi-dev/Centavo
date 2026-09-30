import 'package:centavo/core/database/converters.dart';
import 'package:centavo/core/database/tables/categories_table.dart';
import 'package:drift/drift.dart';

@DataClassName('BudgetRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX budgets_active_category_month ON budgets '
  '(category_id, month) WHERE deleted_at IS NULL',
)
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get month => text().map(const YearMonthConverter())();
  IntColumn get limitMinor =>
      // ignore: recursive_getters, Drift's documented check() pattern
      integer().check(limitMinor.isBiggerThanValue(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

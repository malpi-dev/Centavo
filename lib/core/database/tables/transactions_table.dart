import 'package:centavo/core/database/converters.dart';
import 'package:centavo/core/database/tables/categories_table.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:drift/drift.dart';

@DataClassName('TransactionRow')
@TableIndex.sql(
  'CREATE INDEX transactions_occurred_on ON transactions (occurred_on) '
  'WHERE deleted_at IS NULL',
)
@TableIndex(name: 'transactions_category_id', columns: {#categoryId})
@TableIndex(name: 'transactions_updated_at', columns: {#updatedAt})
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => textEnum<TransactionType>()();
  IntColumn get amountMinor =>
      // ignore: recursive_getters, Drift's documented check() pattern
      integer().check(amountMinor.isBiggerThanValue(0))();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get occurredOn => text().map(const LocalDateConverter())();
  TextColumn get note => text().withLength(max: 140).nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

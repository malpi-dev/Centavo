import 'package:centavo/core/domain/transaction_type.dart';
import 'package:drift/drift.dart';

@DataClassName('CategoryRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX categories_active_name_type ON categories '
  '(lower(name), type) WHERE archived_at IS NULL AND deleted_at IS NULL',
)
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get type => textEnum<TransactionType>()();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:drift/drift.dart';

extension TransactionRowX on TransactionRow {
  MoneyTransaction toDomain() => MoneyTransaction(
    id: id,
    type: type,
    amountMinor: amountMinor,
    categoryId: categoryId,
    occurredOn: occurredOn,
    note: note,
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    deletedAt: deletedAt?.toUtc(),
  );
}

extension TransactionToCompanion on MoneyTransaction {
  TransactionsCompanion toCompanion() => TransactionsCompanion.insert(
    id: id,
    type: type,
    amountMinor: amountMinor,
    categoryId: categoryId,
    occurredOn: occurredOn,
    note: Value(note),
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
    deletedAt: Value(deletedAt?.toUtc()),
  );
}

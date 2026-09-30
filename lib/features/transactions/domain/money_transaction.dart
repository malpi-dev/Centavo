import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'money_transaction.freezed.dart';

/// Named "MoneyTransaction" because "Transaction" collides with Drift.
@freezed
abstract class MoneyTransaction with _$MoneyTransaction {
  const factory MoneyTransaction({
    required String id,
    required TransactionType type,

    /// > 0; the sign comes from [type].
    required int amountMinor,
    required String categoryId,
    required LocalDate occurredOn,
    required DateTime createdAt,
    required DateTime updatedAt,

    /// Trimmed, null when empty, <= 140 chars.
    String? note,
    DateTime? deletedAt,
  }) = _MoneyTransaction;
}

@freezed
abstract class TransactionDraft with _$TransactionDraft {
  const factory TransactionDraft({
    required TransactionType type,
    required int amountMinor,
    required String categoryId,
    required LocalDate occurredOn,
    String? note,
  }) = _TransactionDraft;
}

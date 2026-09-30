import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/backup/data/dtos/json_converters.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:json_annotation/json_annotation.dart';

part 'transaction_dto.g.dart';

@JsonSerializable()
@UtcDateTimeConverter()
@LocalDateConverter()
class TransactionDto {
  const TransactionDto({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.type,
    required this.amountMinor,
    required this.occurredOn,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.deletedAt,
  });

  factory TransactionDto.fromDomain(
    MoneyTransaction t, {
    required String userId,
  }) => TransactionDto(
    id: t.id,
    userId: userId,
    categoryId: t.categoryId,
    type: t.type,
    amountMinor: t.amountMinor,
    occurredOn: t.occurredOn,
    note: t.note,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
    deletedAt: t.deletedAt,
  );

  factory TransactionDto.fromJson(Map<String, dynamic> json) =>
      _$TransactionDtoFromJson(json);

  final String id;
  final String userId;
  final String categoryId;
  final TransactionType type;
  final int amountMinor;
  final LocalDate occurredOn;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Map<String, dynamic> toJson() => _$TransactionDtoToJson(this);

  MoneyTransaction toDomain() => MoneyTransaction(
    id: id,
    type: type,
    amountMinor: amountMinor,
    categoryId: categoryId,
    occurredOn: occurredOn,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

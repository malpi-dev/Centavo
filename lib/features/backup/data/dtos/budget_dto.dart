import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/backup/data/dtos/json_converters.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:json_annotation/json_annotation.dart';

part 'budget_dto.g.dart';

@JsonSerializable()
@UtcDateTimeConverter()
@YearMonthConverter()
class BudgetDto {
  const BudgetDto({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.month,
    required this.limitMinor,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory BudgetDto.fromDomain(Budget b, {required String userId}) => BudgetDto(
    id: b.id,
    userId: userId,
    categoryId: b.categoryId,
    month: b.month,
    limitMinor: b.limitMinor,
    createdAt: b.createdAt,
    updatedAt: b.updatedAt,
    deletedAt: b.deletedAt,
  );

  factory BudgetDto.fromJson(Map<String, dynamic> json) =>
      _$BudgetDtoFromJson(json);

  final String id;
  final String userId;
  final String categoryId;
  final YearMonth month;
  final int limitMinor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Map<String, dynamic> toJson() => _$BudgetDtoToJson(this);

  Budget toDomain() => Budget(
    id: id,
    categoryId: categoryId,
    month: month,
    limitMinor: limitMinor,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

import 'package:centavo/core/domain/year_month.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget.freezed.dart';

@freezed
abstract class Budget with _$Budget {
  const factory Budget({
    required String id,

    /// Expense categories only.
    required String categoryId,
    required YearMonth month,

    /// > 0.
    required int limitMinor,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Budget;
}

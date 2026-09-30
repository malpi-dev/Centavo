import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:drift/drift.dart';

class LocalDateConverter extends TypeConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromSql(String fromDb) => LocalDate.parse(fromDb);

  @override
  String toSql(LocalDate value) => value.toIso();
}

/// Budgets store the first day of the month ('2026-10-01'), like Supabase's
/// `month date`.
class YearMonthConverter extends TypeConverter<YearMonth, String> {
  const YearMonthConverter();

  @override
  YearMonth fromSql(String fromDb) => YearMonth.parse(fromDb);

  @override
  String toSql(YearMonth value) => value.toFirstDayIso();
}

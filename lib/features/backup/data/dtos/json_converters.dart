import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:json_annotation/json_annotation.dart';

/// ISO-8601 UTC on the way out; any offset is normalised to UTC on the way in.
/// json_serializable reuses it for nullable fields.
class UtcDateTimeConverter implements JsonConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json).toUtc();

  @override
  String toJson(DateTime object) => object.toUtc().toIso8601String();
}

/// `occurred_on`: 'YYYY-MM-DD'.
class LocalDateConverter implements JsonConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromJson(String json) => LocalDate.parse(json);

  @override
  String toJson(LocalDate object) => object.toIso();
}

/// `month`: 'YYYY-MM-01'.
class YearMonthConverter implements JsonConverter<YearMonth, String> {
  const YearMonthConverter();

  @override
  YearMonth fromJson(String json) => YearMonth.parse(json);

  @override
  String toJson(YearMonth object) => object.toFirstDayIso();
}

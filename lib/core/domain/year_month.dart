import 'package:centavo/core/domain/local_date.dart';
import 'package:meta/meta.dart';

/// A calendar month.
@immutable
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month)
    : assert(month >= 1 && month <= 12, 'month must be between 1 and 12');

  factory YearMonth.fromLocalDate(LocalDate date) =>
      YearMonth(date.year, date.month);

  /// Accepts `YYYY-MM` and `YYYY-MM-DD` (uses the first 7 characters).
  factory YearMonth.parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) {
      throw FormatException('Expected YYYY-MM or YYYY-MM-DD', value);
    }
    final month = int.parse(match.group(2)!);
    if (month < 1 || month > 12) {
      throw FormatException('Month out of range', value);
    }
    return YearMonth(int.parse(match.group(1)!), month);
  }

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})(?:-\d{2})?$');

  final int year;
  final int month;

  /// Negative values are allowed: 2026-01 + (-1) = 2025-12.
  YearMonth addMonths(int months) {
    final index = year * 12 + (month - 1) + months;
    return YearMonth(index ~/ 12, index % 12 + 1);
  }

  YearMonth get previous => addMonths(-1);

  YearMonth get next => addMonths(1);

  LocalDate get firstDay => LocalDate(year, month, 1);

  /// Exclusive upper bound for queries.
  LocalDate get firstDayOfNextMonth => next.firstDay;

  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  bool contains(LocalDate date) => date.year == year && date.month == month;

  /// `YYYY-MM`.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  /// `YYYY-MM-01`: how budgets.month is persisted.
  String toFirstDayIso() => '${toIso()}-01';

  @override
  int compareTo(YearMonth other) {
    if (year != other.year) return year.compareTo(other.year);
    return month.compareTo(other.month);
  }

  bool operator <(YearMonth other) => compareTo(other) < 0;
  bool operator <=(YearMonth other) => compareTo(other) <= 0;
  bool operator >(YearMonth other) => compareTo(other) > 0;
  bool operator >=(YearMonth other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => toIso();
}

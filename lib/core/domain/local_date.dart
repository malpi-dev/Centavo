import 'package:meta/meta.dart';

/// A calendar day without time or time zone.
@immutable
class LocalDate implements Comparable<LocalDate> {
  /// Throws [ArgumentError] if the date does not exist (e.g. 2026-02-30).
  factory LocalDate(int year, int month, int day) {
    if (!_exists(year, month, day)) {
      throw ArgumentError('Invalid date: $year-$month-$day');
    }
    return LocalDate._(year, month, day);
  }

  /// Takes year/month/day as they are in [dateTime]; the caller decides
  /// whether it is local or UTC.
  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate(dateTime.year, dateTime.month, dateTime.day);

  /// Parses `YYYY-MM-DD`; throws [FormatException] otherwise.
  factory LocalDate.parse(String iso) {
    final match = _isoPattern.firstMatch(iso);
    if (match == null) {
      throw FormatException('Expected YYYY-MM-DD', iso);
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (!_exists(year, month, day)) {
      throw FormatException('Date does not exist', iso);
    }
    return LocalDate._(year, month, day);
  }

  const LocalDate._(this.year, this.month, this.day);

  static bool _exists(int year, int month, int day) {
    final check = DateTime.utc(year, month, day);
    return check.year == year && check.month == month && check.day == day;
  }

  static final _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  /// Zero-padded `YYYY-MM-DD`.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// Local midnight, meant for date pickers.
  DateTime toDateTime() => DateTime(year, month, day);

  /// Uses UTC internally to avoid daylight saving issues.
  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(DateTime.utc(year, month, day + days));

  /// 1 = Monday ... 7 = Sunday.
  int get weekday => DateTime.utc(year, month, day).weekday;

  bool isBefore(LocalDate other) => compareTo(other) < 0;

  bool isAfter(LocalDate other) => compareTo(other) > 0;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

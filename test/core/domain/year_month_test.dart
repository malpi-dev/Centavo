import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('addMonths crosses years in both directions', () {
    expect(const YearMonth(2026, 1).addMonths(-1), const YearMonth(2025, 12));
    expect(const YearMonth(2026, 11).addMonths(3), const YearMonth(2027, 2));
    expect(const YearMonth(2026, 1).addMonths(-13), const YearMonth(2024, 12));
    expect(const YearMonth(2026, 6).addMonths(0), const YearMonth(2026, 6));
  });

  test('previous and next', () {
    expect(const YearMonth(2026, 12).next, const YearMonth(2027, 1));
    expect(const YearMonth(2026, 1).previous, const YearMonth(2025, 12));
  });

  test('daysInMonth', () {
    expect(const YearMonth(2028, 2).daysInMonth, 29);
    expect(const YearMonth(2026, 2).daysInMonth, 28);
    expect(const YearMonth(2026, 12).daysInMonth, 31);
    expect(const YearMonth(2026, 4).daysInMonth, 30);
  });

  test('bounds and contains', () {
    const m = YearMonth(2026, 12);
    expect(m.firstDay, LocalDate(2026, 12, 1));
    expect(m.firstDayOfNextMonth, LocalDate(2027, 1, 1));
    expect(m.contains(LocalDate(2026, 12, 31)), isTrue);
    expect(m.contains(LocalDate(2027, 1, 1)), isFalse);
    expect(m.contains(LocalDate(2025, 12, 1)), isFalse);
  });

  test('iso formats', () {
    expect(const YearMonth(2026, 3).toIso(), '2026-03');
    expect(const YearMonth(2026, 3).toFirstDayIso(), '2026-03-01');
  });

  test('parse accepts both formats', () {
    expect(YearMonth.parse('2026-03'), const YearMonth(2026, 3));
    expect(YearMonth.parse('2026-03-01'), const YearMonth(2026, 3));
    expect(() => YearMonth.parse('2026-13'), throwsFormatException);
    expect(() => YearMonth.parse('x'), throwsFormatException);
  });

  test('fromLocalDate and ordering', () {
    expect(
      YearMonth.fromLocalDate(LocalDate(2026, 3, 9)),
      const YearMonth(2026, 3),
    );
    expect(const YearMonth(2026, 3) < const YearMonth(2026, 4), isTrue);
    expect(const YearMonth(2027, 1) > const YearMonth(2026, 12), isTrue);
    expect(const YearMonth(2026, 3) >= const YearMonth(2026, 3), isTrue);
    expect(const YearMonth(2026, 3) <= const YearMonth(2026, 3), isTrue);
  });
}

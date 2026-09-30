import 'package:centavo/core/domain/local_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse and toIso round trip', () {
    expect(LocalDate.parse('2026-03-07').toIso(), '2026-03-07');
    expect(LocalDate(2026, 3, 7), LocalDate.parse('2026-03-07'));
    expect(LocalDate(7, 1, 2).toIso(), '0007-01-02');
  });

  test('invalid dates throw', () {
    expect(() => LocalDate(2026, 2, 30), throwsArgumentError);
    expect(() => LocalDate(2026, 13, 1), throwsArgumentError);
    expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
    expect(() => LocalDate.parse('2026-2-3'), throwsFormatException);
    expect(() => LocalDate.parse('nope'), throwsFormatException);
  });

  test('addDays crosses month, year and DST boundaries', () {
    expect(LocalDate(2026, 1, 31).addDays(1), LocalDate(2026, 2, 1));
    expect(LocalDate(2026, 12, 31).addDays(1), LocalDate(2027, 1, 1));
    expect(LocalDate(2026, 3, 1).addDays(-1), LocalDate(2026, 2, 28));
    expect(LocalDate(2026, 3, 7).addDays(2), LocalDate(2026, 3, 9));
    expect(LocalDate(2026, 10, 24).addDays(2), LocalDate(2026, 10, 26));
    expect(LocalDate(2028, 2, 28).addDays(1), LocalDate(2028, 2, 29));
  });

  test('weekday is 1 = Monday ... 7 = Sunday', () {
    expect(LocalDate(2026, 9, 28).weekday, 1);
    expect(LocalDate(2026, 10, 4).weekday, 7);
  });

  test('comparison and equality', () {
    final a = LocalDate(2026, 5, 1);
    final b = LocalDate(2026, 5, 2);
    expect(a.isBefore(b), isTrue);
    expect(b.isAfter(a), isTrue);
    expect(a.compareTo(a), 0);
    expect(a.hashCode, LocalDate(2026, 5, 1).hashCode);
  });

  test('toDateTime and fromDateTime', () {
    final d = LocalDate(2026, 5, 1);
    expect(d.toDateTime(), DateTime(2026, 5));
    expect(LocalDate.fromDateTime(DateTime(2026, 5, 1, 23, 59)), d);
  });
}

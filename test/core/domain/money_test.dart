import 'package:centavo/core/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('add and subtract', () {
    expect(
      const Money(100, 'USD') + const Money(250, 'USD'),
      const Money(350, 'USD'),
    );
    expect(
      const Money(100, 'USD') - const Money(250, 'USD'),
      const Money(-150, 'USD'),
    );
    expect(
      (const Money(100, 'USD') - const Money(250, 'USD')).isNegative,
      isTrue,
    );
    expect(const Money.zero('USD').isZero, isTrue);
  });

  test('different currencies throw ArgumentError', () {
    expect(
      () => const Money(1, 'USD') + const Money(1, 'EUR'),
      throwsArgumentError,
    );
    expect(
      () => const Money(1, 'USD') - const Money(1, 'EUR'),
      throwsArgumentError,
    );
    expect(
      () => const Money(1, 'USD').compareTo(const Money(1, 'EUR')),
      throwsArgumentError,
    );
  });

  test('basisPointsOf uses truncated integer math', () {
    expect(const Money(1, 'USD').basisPointsOf(const Money(3, 'USD')), 3333);
    expect(const Money(50, 'USD').basisPointsOf(const Money(100, 'USD')), 5000);
    expect(
      const Money(150, 'USD').basisPointsOf(const Money(100, 'USD')),
      15000,
    );
    expect(const Money(50, 'USD').basisPointsOf(const Money.zero('USD')), 0);
  });

  test('ratioOf is a display ratio', () {
    expect(const Money(50, 'USD').ratioOf(const Money(200, 'USD')), 0.25);
    expect(const Money(50, 'USD').ratioOf(const Money.zero('USD')), 0);
  });

  test('compareTo and equality', () {
    expect(const Money(1, 'USD').compareTo(const Money(2, 'USD')), lessThan(0));
    expect(const Money(2, 'USD'), const Money(2, 'USD'));
    expect(const Money(2, 'USD').hashCode, const Money(2, 'USD').hashCode);
    expect(const Money(2, 'USD') == const Money(2, 'EUR'), isFalse);
  });
}

import 'package:centavo/core/domain/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currencyByCode', () {
    expect(currencyByCode('CLP').minorUnits, 0);
    expect(currencyByCode('USD').minorUnits, 2);
    expect(() => currencyByCode('JPY'), throwsArgumentError);
  });

  test('defaultCurrencyForCountry', () {
    expect(defaultCurrencyForCountry('ES'), 'EUR');
    expect(defaultCurrencyForCountry('DE'), 'EUR');
    expect(defaultCurrencyForCountry('MX'), 'MXN');
    expect(defaultCurrencyForCountry('br'), 'BRL');
    expect(defaultCurrencyForCountry('JP'), 'USD');
    expect(defaultCurrencyForCountry(null), 'USD');
  });

  test('all supported currencies are resolvable', () {
    for (final c in supportedCurrencies) {
      expect(currencyByCode(c.code), c);
    }
  });
}

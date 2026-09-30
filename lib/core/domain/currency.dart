import 'package:meta/meta.dart';

@immutable
class Currency {
  const Currency({
    required this.code,
    required this.name,
    required this.minorUnits,
  });

  final String code;
  final String name;
  final int minorUnits;

  @override
  bool operator ==(Object other) =>
      other is Currency &&
      other.code == code &&
      other.name == name &&
      other.minorUnits == minorUnits;

  @override
  int get hashCode => Object.hash(code, name, minorUnits);

  @override
  String toString() => 'Currency($code)';
}

const supportedCurrencies = <Currency>[
  Currency(code: 'USD', name: 'US Dollar', minorUnits: 2),
  Currency(code: 'EUR', name: 'Euro', minorUnits: 2),
  Currency(code: 'MXN', name: 'Mexican Peso', minorUnits: 2),
  Currency(code: 'COP', name: 'Colombian Peso', minorUnits: 2),
  Currency(code: 'ARS', name: 'Argentine Peso', minorUnits: 2),
  Currency(code: 'CLP', name: 'Chilean Peso', minorUnits: 0),
  Currency(code: 'PEN', name: 'Peruvian Sol', minorUnits: 2),
  Currency(code: 'BRL', name: 'Brazilian Real', minorUnits: 2),
];

/// Throws [ArgumentError] for unsupported codes.
Currency currencyByCode(String code) {
  for (final currency in supportedCurrencies) {
    if (currency.code == code) return currency;
  }
  throw ArgumentError.value(code, 'code', 'Unsupported currency');
}

const _euroAreaCountries = <String>{
  'AT', 'BE', 'CY', 'DE', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR', //
  'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PT', 'SI', 'SK',
};

const _countryCurrencies = <String, String>{
  'US': 'USD',
  'MX': 'MXN',
  'CO': 'COP',
  'AR': 'ARS',
  'CL': 'CLP',
  'PE': 'PEN',
  'BR': 'BRL',
};

/// Euro-area countries map to EUR; unknown countries or null map to USD.
String defaultCurrencyForCountry(String? countryCode) {
  if (countryCode == null) return 'USD';
  final code = countryCode.toUpperCase();
  if (_euroAreaCountries.contains(code)) return 'EUR';
  return _countryCurrencies[code] ?? 'USD';
}

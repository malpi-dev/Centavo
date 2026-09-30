import 'package:centavo/core/domain/currency.dart';
import 'package:centavo/core/domain/money.dart';
import 'package:intl/intl.dart';

/// Display only: the conversion to double never feeds business logic.
String formatMoney(Money money, {bool signed = false}) {
  final minorUnits = currencyByCode(money.currencyCode).minorUnits;
  final format = NumberFormat.simpleCurrency(
    locale: 'en_US',
    name: money.currencyCode,
    decimalDigits: minorUnits,
  );
  var divisor = 1;
  for (var i = 0; i < minorUnits; i++) {
    divisor *= 10;
  }
  final text = format.format(money.amountMinor.abs() / divisor);
  if (money.amountMinor < 0) return '−$text';
  if (signed && money.amountMinor > 0) return '+$text';
  return text;
}

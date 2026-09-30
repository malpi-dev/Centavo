import 'package:centavo/core/errors/domain_error.dart';

final _amountPattern = RegExp(r'^(\d+)(?:[.,](\d*))?$');

/// Parses user input ("12.5", "12,50", "1250") into minor units. Accepts at
/// most one '.' or ',' as decimal separator, no thousands separators, no sign,
/// at most 12 integer digits.
///
/// Throws [ValidationError] (required | invalidFormat | tooManyDecimals). Zero
/// is returned as 0 (the caller decides whether 0 is allowed).
int parseAmountToMinor(
  String input, {
  required int minorUnits,
  String field = 'amount',
}) {
  final text = input.trim();
  if (text.isEmpty) {
    throw ValidationError(field, ValidationReason.required);
  }
  final match = _amountPattern.firstMatch(text);
  if (match == null) {
    throw ValidationError(field, ValidationReason.invalidFormat);
  }
  final whole = match.group(1)!;
  final fraction = match.group(2) ?? '';
  if (whole.length > 12) {
    throw ValidationError(field, ValidationReason.invalidFormat);
  }
  if (fraction.length > minorUnits) {
    throw ValidationError(field, ValidationReason.tooManyDecimals);
  }
  var factor = 1;
  for (var i = 0; i < minorUnits; i++) {
    factor *= 10;
  }
  final padded = fraction.padRight(minorUnits, '0');
  final fractionValue = minorUnits == 0 ? 0 : int.parse(padded);
  return int.parse(whole) * factor + fractionValue;
}

/// 1250, 2 -> "12.50"; 5000, 0 -> "5000". Always '.' as decimal separator (CSV
/// and form prefill).
String formatMinorPlain(int amountMinor, {required int minorUnits}) {
  final negative = amountMinor < 0;
  final digits = amountMinor.abs().toString();
  final String body;
  if (minorUnits == 0) {
    body = digits;
  } else {
    final padded = digits.padLeft(minorUnits + 1, '0');
    final split = padded.length - minorUnits;
    body = '${padded.substring(0, split)}.${padded.substring(split)}';
  }
  return negative ? '-$body' : body;
}

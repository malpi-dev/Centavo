import 'package:centavo/core/domain/amount_parser.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher failsWith(ValidationReason reason) => throwsA(
  isA<ValidationError>()
      .having((e) => e.reason, 'reason', reason)
      .having((e) => e.field, 'field', 'amount'),
);

void main() {
  int parse(String s, {int minorUnits = 2}) =>
      parseAmountToMinor(s, minorUnits: minorUnits);

  test('parses valid inputs', () {
    expect(parse('12.5'), 1250);
    expect(parse('12,50'), 1250);
    expect(parse('1250'), 125000);
    expect(parse('0'), 0);
    expect(parse('0.05'), 5);
    expect(parse(' 7 '), 700);
    expect(parse('5000', minorUnits: 0), 5000);
    expect(parse('12.'), 1200);
  });

  test('rejects too many decimals', () {
    expect(
      () => parse('50.5', minorUnits: 0),
      failsWith(ValidationReason.tooManyDecimals),
    );
    expect(() => parse('1.234'), failsWith(ValidationReason.tooManyDecimals));
  });

  test('rejects empty input', () {
    expect(() => parse(''), failsWith(ValidationReason.required));
    expect(() => parse('   '), failsWith(ValidationReason.required));
  });

  test('rejects malformed input', () {
    for (final s in ['1.2.3', '-5', '1,000.00', 'abc', '.5', '1 000']) {
      expect(
        () => parse(s),
        failsWith(ValidationReason.invalidFormat),
        reason: s,
      );
    }
    expect(
      () => parse('1234567890123'),
      failsWith(ValidationReason.invalidFormat),
    );
    expect(parse('123456789012'), 12345678901200);
  });

  test('uses the given field name', () {
    expect(
      () => parseAmountToMinor('', minorUnits: 2, field: 'limit'),
      throwsA(isA<ValidationError>().having((e) => e.field, 'field', 'limit')),
    );
  });

  test('formatMinorPlain', () {
    expect(formatMinorPlain(1250, minorUnits: 2), '12.50');
    expect(formatMinorPlain(5, minorUnits: 2), '0.05');
    expect(formatMinorPlain(5000, minorUnits: 0), '5000');
    expect(formatMinorPlain(0, minorUnits: 2), '0.00');
    expect(formatMinorPlain(-1250, minorUnits: 2), '-12.50');
  });
}

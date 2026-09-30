import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:centavo/features/transactions/domain/transaction_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, ValidationReason> validate({
    String amount = '12.50',
    int minorUnits = 2,
    String? category = 'cat-1',
    String note = '',
  }) => validateTransactionForm(
    amountText: amount,
    minorUnits: minorUnits,
    categoryId: category,
    note: note,
  );

  test('valid form has no errors', () => expect(validate(), isEmpty));

  test('empty amount is required', () {
    expect(validate(amount: '')['amount'], ValidationReason.required);
  });

  test('zero is mustBePositive', () {
    expect(validate(amount: '0')['amount'], ValidationReason.mustBePositive);
    expect(validate(amount: '0.00')['amount'], ValidationReason.mustBePositive);
  });

  test('negative or garbage amount is invalidFormat', () {
    expect(validate(amount: '-5')['amount'], ValidationReason.invalidFormat);
    expect(validate(amount: 'abc')['amount'], ValidationReason.invalidFormat);
  });

  test('too many decimals', () {
    expect(
      validate(amount: '1.234')['amount'],
      ValidationReason.tooManyDecimals,
    );
  });

  test('CLP has no decimals', () {
    expect(validate(amount: '5000', minorUnits: 0), isEmpty);
    expect(
      validate(amount: '5000.5', minorUnits: 0)['amount'],
      ValidationReason.tooManyDecimals,
    );
  });

  test('category is required', () {
    expect(validate(category: null)['category'], ValidationReason.required);
    expect(validate(category: '')['category'], ValidationReason.required);
  });

  test('note of 141 chars is too long, 140 is fine', () {
    expect(validate(note: 'a' * 141)['note'], ValidationReason.tooLong);
    expect(validate(note: 'a' * 140), isEmpty);
  });

  test('reports several errors at once', () {
    final errors = validate(amount: '', category: null, note: 'a' * 200);
    expect(errors.keys, unorderedEquals(['amount', 'category', 'note']));
  });

  test('normalizeNote', () {
    expect(normalizeNote(null), isNull);
    expect(normalizeNote(''), isNull);
    expect(normalizeNote('   '), isNull);
    expect(normalizeNote('  hi  '), 'hi');
  });

  group('assertValidDraft', () {
    TransactionDraft draft({int amount = 100, String? note}) =>
        TransactionDraft(
          type: TransactionType.expense,
          amountMinor: amount,
          categoryId: 'cat-1',
          occurredOn: LocalDate(2026, 10, 5),
          note: note,
        );

    test('accepts a valid draft', () {
      expect(() => assertValidDraft(draft()), returnsNormally);
    });

    test('rejects non-positive amounts', () {
      expect(
        () => assertValidDraft(draft(amount: 0)),
        throwsA(
          isA<ValidationError>()
              .having((e) => e.field, 'field', 'amount')
              .having(
                (e) => e.reason,
                'reason',
                ValidationReason.mustBePositive,
              ),
        ),
      );
      expect(
        () => assertValidDraft(draft(amount: -1)),
        throwsA(isA<ValidationError>()),
      );
    });

    test('rejects long notes', () {
      expect(
        () => assertValidDraft(draft(note: 'a' * 141)),
        throwsA(
          isA<ValidationError>().having((e) => e.field, 'field', 'note'),
        ),
      );
    });
  });
}

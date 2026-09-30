import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/budgets/domain/budget_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid limit', () {
    expect(validateBudgetForm(limitText: '250', minorUnits: 2), isEmpty);
  });

  test('empty, zero and invalid limits report the limit field', () {
    expect(
      validateBudgetForm(limitText: '', minorUnits: 2)['limit'],
      ValidationReason.required,
    );
    expect(
      validateBudgetForm(limitText: '0', minorUnits: 2)['limit'],
      ValidationReason.mustBePositive,
    );
    expect(
      validateBudgetForm(limitText: 'x', minorUnits: 2)['limit'],
      ValidationReason.invalidFormat,
    );
  });
}

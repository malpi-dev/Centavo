import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/categories/domain/category_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, ValidationReason> validate({
    String name = 'Food',
    String icon = 'food',
    int color = 0xFFE65100,
  }) => validateCategoryForm(name: name, icon: icon, color: color);

  test('valid input has no errors', () => expect(validate(), isEmpty));

  test('empty or blank name is required', () {
    expect(validate(name: '')['name'], ValidationReason.required);
    expect(validate(name: '   ')['name'], ValidationReason.required);
  });

  test('31 characters is too long, 30 is fine', () {
    expect(validate(name: 'a' * 31)['name'], ValidationReason.tooLong);
    expect(validate(name: 'a' * 30), isEmpty);
  });

  test('length is measured after normalization', () {
    expect(validate(name: '  ${'a' * 30}  '), isEmpty);
  });

  test('normalizes whitespace', () {
    expect(normalizeCategoryName('  Eating   out '), 'Eating out');
    expect(normalizeCategoryName('a\t\nb'), 'a b');
  });

  test('icon and color outside the sets are notAllowed', () {
    final errors = validate(icon: 'rocket', color: 0xFF000000);
    expect(errors['icon'], ValidationReason.notAllowed);
    expect(errors['color'], ValidationReason.notAllowed);
  });
}

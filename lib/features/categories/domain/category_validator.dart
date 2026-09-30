import 'package:centavo/core/domain/category_palette.dart';
import 'package:centavo/core/errors/domain_error.dart';

const maxCategoryNameLength = 30;

/// Trims and collapses inner whitespace ("  Eating   out " -> "Eating out").
String normalizeCategoryName(String name) =>
    name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');

/// Returns field errors (empty map = valid). Fields: 'name', 'icon', 'color'.
Map<String, ValidationReason> validateCategoryForm({
  required String name,
  required String icon,
  required int color,
}) {
  final errors = <String, ValidationReason>{};
  final normalized = normalizeCategoryName(name);
  if (normalized.isEmpty) {
    errors['name'] = ValidationReason.required;
  } else if (normalized.length > maxCategoryNameLength) {
    errors['name'] = ValidationReason.tooLong;
  }
  if (!categoryIconKeys.contains(icon)) {
    errors['icon'] = ValidationReason.notAllowed;
  }
  if (!categoryColorPalette.contains(color)) {
    errors['color'] = ValidationReason.notAllowed;
  }
  return errors;
}

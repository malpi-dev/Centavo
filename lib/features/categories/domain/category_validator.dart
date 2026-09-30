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

/// First free name among `name`, `name 2`, `name 3`... ([isTaken] tells
/// whether a candidate clashes). The original is cut to 28 characters so the
/// suffix always fits in [maxCategoryNameLength].
String disambiguateCategoryName(
  String name,
  bool Function(String candidate) isTaken,
) {
  if (!isTaken(name)) return name;
  final base = name.length > maxCategoryNameLength - 2
      ? name.substring(0, maxCategoryNameLength - 2)
      : name;
  for (var n = 2; ; n++) {
    final candidate = '$base $n';
    if (!isTaken(candidate)) return candidate;
  }
}

import 'package:centavo/core/domain/category_palette.dart';
import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/presentation/money_format.dart';
import 'package:centavo/core/theme/app_colors.dart';
import 'package:centavo/core/theme/centavo_colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatMoney', () {
    expect(formatMoney(const Money(123456, 'USD')), r'$1,234.56');
    expect(formatMoney(const Money(-500, 'USD')), r'−$5.00');
    expect(formatMoney(const Money(500, 'USD'), signed: true), r'+$5.00');
    expect(formatMoney(const Money(5000, 'CLP')), contains('5,000'));
  });

  test('category colors map to dark variants by index', () {
    expect(AppColors.categoryDark.length, categoryColorPalette.length);
    const dark = CentavoColors.dark();
    const light = CentavoColors.light();
    final stored = categoryColorPalette[2];
    expect(light.category(stored), Color(stored));
    expect(dark.category(stored), Color(AppColors.categoryDark[2]));
    expect(dark.category(0xFF123456), const Color(0xFF123456));
  });
}

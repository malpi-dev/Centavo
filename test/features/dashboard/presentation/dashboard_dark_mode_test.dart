import 'package:centavo/core/domain/category_palette.dart';
import 'package:centavo/core/theme/app_colors.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';
import '../../transactions/presentation/transactions_test_helpers.dart';
import 'dashboard_test_helpers.dart';

void main() {
  testCentavo('dark mode builds and uses the dark palette in the donut', (
    tester,
  ) async {
    final container = await openDashboard(
      tester,
      settings: const AppSettings(
        onboardingCompleted: true,
        themePreference: AppThemePreference.dark,
      ),
    );
    await addTransaction(
      tester,
      container,
      amountMinor: 5000,
    );
    await addTransaction(tester, container, amountMinor: 100);

    expect(tester.takeException(), isNull);
    final pie = tester.widget<PieChart>(
      find.byKey(const Key('dashboard-donut')),
    );
    final food = buildDefaultCategories(
      DateTime.utc(2026),
    ).firstWhere((c) => c.id == DefaultCategoryIds.food);
    final index = categoryColorPalette.indexOf(food.color);
    expect(pie.data.sections.first.color, Color(AppColors.categoryDark[index]));
    expect(pie.data.sections.first.color, isNot(Color(food.color)));

    expect(tester.takeException(), isNull);
  });
}

import 'package:centavo/core/domain/category_palette.dart';
import 'package:centavo/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Semantic colors that Material's [ColorScheme] does not cover.
@immutable
class CentavoColors extends ThemeExtension<CentavoColors> {
  const CentavoColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.onTrack,
    required this.exceeded,
    required this.chartGrid,
    required this.isDark,
  });

  const CentavoColors.light()
    : income = AppColors.incomeLight,
      expense = AppColors.expenseLight,
      warning = AppColors.warningLight,
      onTrack = AppColors.incomeLight,
      exceeded = AppColors.errorLight,
      chartGrid = const Color(0x1F1B1F1D),
      isDark = false;

  const CentavoColors.dark()
    : income = AppColors.incomeDark,
      expense = AppColors.expenseDark,
      warning = AppColors.warningDark,
      onTrack = AppColors.incomeDark,
      exceeded = AppColors.errorDark,
      chartGrid = const Color(0x1FE6EAE7),
      isDark = true;

  final Color income;
  final Color expense;
  final Color warning;
  final Color onTrack;
  final Color exceeded;
  final Color chartGrid;
  final bool isDark;

  /// Foreground for content drawn on top of a category color.
  Color get onCategory => const Color(0xFFFFFFFF);

  /// Returns the stored (light) ARGB as is in the light theme and the dark
  /// variant of the same palette index in the dark theme.
  Color category(int storedArgb) {
    if (isDark) {
      final index = categoryColorPalette.indexOf(storedArgb);
      if (index != -1) return Color(AppColors.categoryDark[index]);
    }
    return Color(storedArgb);
  }

  @override
  CentavoColors copyWith({
    Color? income,
    Color? expense,
    Color? warning,
    Color? onTrack,
    Color? exceeded,
    Color? chartGrid,
    bool? isDark,
  }) {
    return CentavoColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
      onTrack: onTrack ?? this.onTrack,
      exceeded: exceeded ?? this.exceeded,
      chartGrid: chartGrid ?? this.chartGrid,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  CentavoColors lerp(ThemeExtension<CentavoColors>? other, double t) {
    if (other is! CentavoColors) return this;
    return CentavoColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onTrack: Color.lerp(onTrack, other.onTrack, t)!,
      exceeded: Color.lerp(exceeded, other.exceeded, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension CentavoColorsX on BuildContext {
  CentavoColors get colors => Theme.of(this).extension<CentavoColors>()!;
}

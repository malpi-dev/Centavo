import 'package:centavo/core/theme/app_colors.dart';
import 'package:centavo/core/theme/centavo_colors.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final secondary = isDark
        ? AppColors.secondaryDark
        : AppColors.secondaryLight;
    final background = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final onSurface = isDark
        ? AppColors.onSurfaceDark
        : AppColors.onSurfaceLight;
    final error = isDark ? AppColors.errorDark : AppColors.errorLight;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primaryLight,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          secondary: secondary,
          surface: surface,
          onSurface: onSurface,
          error: error,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: _textTheme(brightness, onSurface),
      extensions: [
        if (isDark) const CentavoColors.dark() else const CentavoColors.light(),
      ],
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.16),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness, Color onSurface) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    TextStyle? title(TextStyle? s, FontWeight w) =>
        s?.copyWith(fontFamily: 'Manrope', fontWeight: w);
    TextStyle? body(TextStyle? s) => s?.copyWith(fontFamily: 'Inter');

    return TextTheme(
      displayLarge: title(base.displayLarge, FontWeight.w800),
      displayMedium: title(base.displayMedium, FontWeight.w800),
      displaySmall: title(base.displaySmall, FontWeight.w800),
      headlineLarge: title(base.headlineLarge, FontWeight.w700),
      headlineMedium: title(base.headlineMedium, FontWeight.w700),
      headlineSmall: title(base.headlineSmall, FontWeight.w700),
      titleLarge: title(base.titleLarge, FontWeight.w600),
      titleMedium: title(base.titleMedium, FontWeight.w600),
      titleSmall: title(base.titleSmall, FontWeight.w600),
      bodyLarge: body(base.bodyLarge),
      bodyMedium: body(base.bodyMedium),
      bodySmall: body(base.bodySmall),
      labelLarge: body(base.labelLarge),
      labelMedium: body(base.labelMedium),
      labelSmall: body(base.labelSmall),
    ).apply(bodyColor: onSurface, displayColor: onSurface);
  }
}

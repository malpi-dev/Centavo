import 'package:flutter/painting.dart';

/// Brand and semantic color tokens (definition section 11). This folder is the
/// only place where raw `Color(0x...)` values are allowed.
abstract final class AppColors {
  static const primaryLight = Color(0xFF1F6F5C);
  static const primaryDark = Color(0xFF6FD3B5);
  static const secondaryLight = Color(0xFFB8692E);
  static const secondaryDark = Color(0xFFE9A56B);
  static const backgroundLight = Color(0xFFF7F6F2);
  static const backgroundDark = Color(0xFF0F1412);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF18201D);
  static const onSurfaceLight = Color(0xFF1B1F1D);
  static const onSurfaceDark = Color(0xFFE6EAE7);
  static const incomeLight = Color(0xFF2E8B57);
  static const incomeDark = Color(0xFF7BD69A);
  static const expenseLight = Color(0xFFC8453B);
  static const expenseDark = Color(0xFFFF8A7F);
  static const warningLight = Color(0xFFD99A1E);
  static const warningDark = Color(0xFFF2C055);
  static const errorLight = Color(0xFFB3261E);
  static const errorDark = Color(0xFFF2B8B5);

  /// Dark variants of `categoryColorPalette`, same order.
  static const categoryDark = <int>[
    0xFF81C784,
    0xFF4DB6AC,
    0xFF64B5F6,
    0xFF9FA8DA,
    0xFFCE93D8,
    0xFFF48FB1,
    0xFFEF9A9A,
    0xFFFFB74D,
    0xFFFFD54F,
    0xFFBCAAA4,
    0xFFB0BEC5,
    0xFFE9A56B,
  ];
}

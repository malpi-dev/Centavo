import 'package:centavo/core/presentation/category_icons.dart';
import 'package:centavo/core/theme/centavo_colors.dart';
import 'package:flutter/material.dart';

/// Circle with the category color at 18 % opacity and its icon on top.
/// Null [icon] or [color] (the "Others" slice, a missing category) renders a
/// neutral placeholder.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({this.icon, this.color, this.size = 40, super.key});

  final String? icon;
  final int? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final color = this.color;
    final resolved = (icon == null || color == null)
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : context.colors.category(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: resolved.withValues(alpha: 0.18),
      ),
      child: Icon(
        icon == null ? Icons.more_horiz : categoryIcon(icon),
        color: resolved,
        size: size * 0.55,
      ),
    );
  }
}

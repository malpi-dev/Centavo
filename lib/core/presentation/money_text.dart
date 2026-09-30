import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/presentation/money_format.dart';
import 'package:centavo/core/theme/centavo_colors.dart';
import 'package:flutter/material.dart';

enum MoneyTone { income, expense, neutral }

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.money, {
    this.tone = MoneyTone.neutral,
    this.style,
    super.key,
  });

  final Money money;
  final MoneyTone tone;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (tone) {
      MoneyTone.income => colors.income,
      MoneyTone.expense => colors.expense,
      MoneyTone.neutral => null,
    };
    final base = style ?? Theme.of(context).textTheme.bodyLarge;
    return Text(
      formatMoney(money),
      style: base?.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

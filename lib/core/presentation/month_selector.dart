import 'package:centavo/core/domain/year_month.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    required this.month,
    required this.onChanged,
    this.maxMonth,
    super.key,
  });

  final YearMonth month;
  final ValueChanged<YearMonth> onChanged;
  final YearMonth? maxMonth;

  @override
  Widget build(BuildContext context) {
    final canGoNext = maxMonth == null || month < maxMonth!;
    final label = DateFormat.yMMMM('en_US').format(DateTime(month.year, month.month));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const Key('month-prev'),
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(month.previous),
        ),
        Text(
          label,
          key: const Key('month-label'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          key: const Key('month-next'),
          icon: const Icon(Icons.chevron_right),
          onPressed: canGoNext ? () => onChanged(month.next) : null,
        ),
      ],
    );
  }
}

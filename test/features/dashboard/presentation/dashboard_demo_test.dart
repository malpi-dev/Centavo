import 'package:centavo/features/demo/data/demo_dataset.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';
import 'dashboard_test_helpers.dart';

void main() {
  testCentavo('demo: legend has top 5 + Others, 6 bar groups, Coffee first', (
    tester,
  ) async {
    await pumpDemo(tester);

    for (var i = 0; i < 6; i++) {
      expect(find.byKey(Key('donut-legend-$i')), findsOneWidget, reason: '$i');
    }
    expect(find.byKey(const Key('donut-legend-6')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('donut-legend-5')),
        matching: find.text('Others'),
      ),
      findsOneWidget,
    );

    final pie = tester.widget<PieChart>(
      find.byKey(const Key('dashboard-donut')),
    );
    expect(pie.data.sections, hasLength(6));

    await tester.scrollUntilVisible(
      find.byKey(const Key('dashboard-trend')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    final bars = tester.widget<BarChart>(
      find.byKey(const Key('dashboard-trend')),
    );
    expect(bars.data.barGroups, hasLength(6));
    expect(bars.data.barGroups.every((g) => g.barRods.length == 2), isTrue);

    await tester.scrollUntilVisible(
      find.byKey(const Key('dashboard-budgets')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('dashboard-budget-'),
    );
    expect(rows, findsNWidgets(3));
    // Coffee is the most over-spent budget of the current month.
    expect(
      tester
          .getTopLeft(
            find.byKey(const Key('dashboard-budget-${DemoDataset.coffeeId}')),
          )
          .dy,
      lessThan(tester.getTopLeft(rows.at(1)).dy),
    );
  });
}

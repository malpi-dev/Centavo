import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/core/presentation/async_state_view.dart';
import 'package:centavo/core/presentation/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Widget view(AsyncValue<List<int>> value, {VoidCallback? onRetry}) {
  return AsyncStateView<List<int>>(
    value: value,
    onRetry: onRetry,
    isEmpty: (d) => d.isEmpty,
    empty: const Text('nothing here'),
    data: (d) => Text('items: ${d.length}'),
  );
}

void main() {
  testWidgets('loading shows the skeleton', (tester) async {
    await pumpApp(tester, view(const AsyncLoading()));
    expect(find.byType(SkeletonList), findsOneWidget);
  });

  testWidgets('empty data shows the empty widget', (tester) async {
    await pumpApp(tester, view(const AsyncData([])));
    expect(find.text('nothing here'), findsOneWidget);
  });

  testWidgets('data shows the content', (tester) async {
    await pumpApp(tester, view(const AsyncData([1, 2])));
    expect(find.text('items: 2'), findsOneWidget);
  });

  testWidgets('error shows its message and Retry calls back', (tester) async {
    var retries = 0;
    await pumpApp(
      tester,
      view(
        const AsyncError<List<int>>(NetworkError(), StackTrace.empty),
        onRetry: () => retries++,
      ),
    );
    expect(find.textContaining("You're offline"), findsOneWidget);
    await tester.tap(find.byKey(const Key('error-retry')));
    expect(retries, 1);
  });

  testWidgets('non-domain errors show the unknown message', (tester) async {
    await pumpApp(
      tester,
      view(AsyncError<List<int>>(StateError('boom'), StackTrace.empty)),
    );
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });
}

import 'package:centavo/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the app name', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CentavoApp()));
    await tester.pumpAndSettle();
    expect(find.text('Centavo'), findsOneWidget);
  });
}

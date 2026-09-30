import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_month_provider.g.dart';

/// Month shared by Dashboard, Transactions and Budgets.
@Riverpod(keepAlive: true)
class SelectedMonth extends _$SelectedMonth {
  @override
  YearMonth build() => YearMonth.fromLocalDate(ref.read(clockProvider).today());

  void previous() => state = state.previous;

  void next() => state = state.next;

  // ignore: use_setters_to_change_properties, keeps the spec'd method API
  void set(YearMonth month) => state = month;
}

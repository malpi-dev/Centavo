import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_form_controller.g.dart';

@riverpod
class TransactionFormController extends _$TransactionFormController {
  @override
  FutureOr<void> build() {}

  Future<void> create(TransactionDraft draft) => _run(
    () => ref.read(transactionRepositoryProvider).create(draft),
  );

  Future<void> edit(MoneyTransaction transaction) => _run(
    () => ref.read(transactionRepositoryProvider).update(transaction),
  );

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
  }
}

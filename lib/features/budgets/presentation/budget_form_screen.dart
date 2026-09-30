import 'package:centavo/core/domain/amount_parser.dart';
import 'package:centavo/core/domain/currency.dart';
import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/core/presentation/async_state_view.dart';
import 'package:centavo/core/presentation/category_avatar.dart';
import 'package:centavo/core/presentation/empty_state.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/money_format.dart';
import 'package:centavo/core/presentation/root_scaffold_messenger.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/budgets/domain/budget_validator.dart';
import 'package:centavo/features/budgets/presentation/budgets_providers.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/presentation/categories_providers.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/features/transactions/presentation/transactions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Sets, edits or removes the monthly limit of an expense category.
/// A null [month] (malformed URL) shows the "not found" state.
class BudgetFormScreen extends ConsumerWidget {
  const BudgetFormScreen({
    required this.categoryId,
    required this.month,
    super.key,
  });

  final String categoryId;
  final YearMonth? month;

  Widget _notFound(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: EmptyState(
      icon: Icons.search_off,
      title: context.l10n.itemNotFound,
      actionLabel: context.l10n.back,
      onAction: () => context.pop(),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = this.month;
    if (month == null || categoryId.isEmpty) return _notFound(context);
    final loading = Scaffold(
      appBar: AppBar(),
      body: const Center(child: CircularProgressIndicator()),
    );
    void retry() {
      ref
        ..invalidate(categoryByIdProvider(categoryId))
        ..invalidate(activeBudgetProvider(categoryId, month));
    }

    return AsyncStateView<Category?>(
      value: ref.watch(categoryByIdProvider(categoryId)),
      onRetry: retry,
      loading: loading,
      data: (category) {
        if (category == null ||
            category.isDeleted ||
            category.type != TransactionType.expense) {
          return _notFound(context);
        }
        return AsyncStateView<Budget?>(
          value: ref.watch(activeBudgetProvider(categoryId, month)),
          onRetry: retry,
          loading: loading,
          data: (budget) =>
              _BudgetForm(category: category, month: month, budget: budget),
        );
      },
    );
  }
}

class _BudgetForm extends ConsumerStatefulWidget {
  const _BudgetForm({
    required this.category,
    required this.month,
    required this.budget,
  });

  final Category category;
  final YearMonth month;
  final Budget? budget;

  @override
  ConsumerState<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<_BudgetForm> {
  late final int _minorUnits = currencyByCode(
    ref.read(settingsControllerProvider).currencyCode,
  ).minorUnits;
  late final TextEditingController _limit = TextEditingController(
    text: widget.budget == null
        ? ''
        : formatMinorPlain(widget.budget!.limitMinor, minorUnits: _minorUnits),
  );
  ValidationReason? _error;

  bool get _isEditing => widget.budget != null;

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  void _onError(Object error) {
    switch (error) {
      case ValidationError(:final reason):
        setState(() => _error = reason);
      default:
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(messageFor(error, context.l10n))),
        );
    }
  }

  Future<void> _save() async {
    final errors = validateBudgetForm(
      limitText: _limit.text,
      minorUnits: _minorUnits,
    );
    setState(() => _error = errors['limit']);
    if (errors.isNotEmpty) return;
    await ref
        .read(budgetFormControllerProvider.notifier)
        .save(
          categoryId: widget.category.id,
          month: widget.month,
          limitMinor: parseAmountToMinor(_limit.text, minorUnits: _minorUnits),
        );
    if (!mounted) return;
    if (!ref.read(budgetFormControllerProvider).hasError) context.pop();
  }

  Future<void> _remove(Budget budget) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeBudgetTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('budget-remove-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.removeBudget),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(budgetFormControllerProvider.notifier).remove(budget.id);
    if (!mounted) return;
    if (ref.read(budgetFormControllerProvider).hasError) return;
    rootScaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.budgetRemoved)));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final category = widget.category;
    final budget = widget.budget;
    final state = ref.watch(budgetFormControllerProvider);
    ref.listen(budgetFormControllerProvider, (_, next) {
      if (next is AsyncError) _onError(next.error);
    });
    final currencyCode = ref.watch(
      settingsControllerProvider.select((s) => s.currencyCode),
    );
    final symbol = NumberFormat.simpleCurrency(
      locale: 'en_US',
      name: currencyCode,
    ).currencySymbol;
    final spent = ref
        .watch(monthTransactionsProvider(widget.month))
        .whenData(
          (list) => list
              .where(
                (t) =>
                    t.type == TransactionType.expense &&
                    t.categoryId == category.id,
              )
              .fold<int>(0, (sum, t) => sum + t.amountMinor),
        )
        .value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.monthlyLimit)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryAvatar(
                  icon: category.icon,
                  color: category.color,
                  label: category.name,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name, style: theme.textTheme.titleMedium),
                      Text(
                        DateFormat.yMMMM(
                          'en_US',
                        ).format(
                          DateTime(widget.month.year, widget.month.month),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Semantics(
              identifier: 'budget-limit',
              child: TextField(
                key: const Key('budget-limit'),
                controller: _limit,
                autofocus: !_isEditing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                ],
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  labelText: l10n.monthlyLimit,
                  prefixText: '$symbol ',
                  errorText: _error == null
                      ? null
                      : validationMessage(_error!, l10n),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ),
            if (spent != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.spentSoFar(
                  formatMoney(Money(spent, currencyCode)),
                ),
                key: const Key('budget-spent-so-far'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                identifier: 'budget-save',
                child: FilledButton(
                  key: const Key('budget-save'),
                  onPressed: state.isLoading ? null : _save,
                  child: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.save),
                ),
              ),
            ),
            if (budget != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('budget-remove'),
                  onPressed: state.isLoading ? null : () => _remove(budget),
                  child: Text(l10n.removeBudget),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

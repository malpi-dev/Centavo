import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/amount_parser.dart';
import 'package:centavo/core/domain/currency.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/core/presentation/async_state_view.dart';
import 'package:centavo/core/presentation/category_avatar.dart';
import 'package:centavo/core/presentation/empty_state.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/root_scaffold_messenger.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/presentation/categories_providers.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:centavo/features/transactions/domain/transaction_validator.dart';
import 'package:centavo/features/transactions/presentation/delete_transaction.dart';
import 'package:centavo/features/transactions/presentation/transaction_form_controller.dart';
import 'package:centavo/features/transactions/presentation/transactions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Create ([transactionId] null) or edit a transaction.
class TransactionFormScreen extends ConsumerWidget {
  const TransactionFormScreen({
    this.transactionId,
    this.initialType = TransactionType.expense,
    super.key,
  });

  final String? transactionId;
  final TransactionType initialType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = transactionId;
    if (id == null) return _TransactionForm(initialType: initialType);
    final l10n = context.l10n;
    return AsyncStateView<MoneyTransaction?>(
      value: ref.watch(transactionByIdProvider(id)),
      onRetry: () => ref.invalidate(transactionByIdProvider(id)),
      loading: Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      data: (transaction) {
        if (transaction == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.search_off,
              title: l10n.itemNotFound,
              actionLabel: l10n.back,
              onAction: () => context.pop(),
            ),
          );
        }
        return _TransactionForm(transaction: transaction);
      },
    );
  }
}

class _TransactionForm extends ConsumerStatefulWidget {
  const _TransactionForm({
    this.transaction,
    this.initialType = TransactionType.expense,
  });

  final MoneyTransaction? transaction;
  final TransactionType initialType;

  @override
  ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<_TransactionForm> {
  late final int _minorUnits = currencyByCode(
    ref.read(settingsControllerProvider).currencyCode,
  ).minorUnits;
  late final TextEditingController _amount = TextEditingController(
    text: widget.transaction == null
        ? ''
        : formatMinorPlain(
            widget.transaction!.amountMinor,
            minorUnits: _minorUnits,
          ),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.transaction?.note ?? '',
  );
  late TransactionType _type = widget.transaction?.type ?? widget.initialType;
  late String? _categoryId = widget.transaction?.categoryId;
  late LocalDate _date =
      widget.transaction?.occurredOn ?? ref.read(clockProvider).today();
  Map<String, ValidationReason> _errors = {};

  bool get _isEditing => widget.transaction != null;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _clearError(String field) {
    if (_errors.containsKey(field)) {
      setState(() => _errors = {..._errors}..remove(field));
    }
  }

  String? _errorFor(String field) {
    final reason = _errors[field];
    return reason == null ? null : validationMessage(reason, context.l10n);
  }

  void _onError(Object error) {
    switch (error) {
      case ValidationError(:final field, :final reason):
        setState(() => _errors = {..._errors, field: reason});
      default:
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(messageFor(error, context.l10n))),
        );
    }
  }

  Future<void> _pickDate() async {
    final today = ref.read(clockProvider).today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = LocalDate.fromDateTime(picked));
  }

  Future<void> _save() async {
    final errors = validateTransactionForm(
      amountText: _amount.text,
      minorUnits: _minorUnits,
      categoryId: _categoryId,
      note: _note.text,
    );
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    final amountMinor = parseAmountToMinor(
      _amount.text,
      minorUnits: _minorUnits,
    );
    final note = normalizeNote(_note.text);
    final controller = ref.read(transactionFormControllerProvider.notifier);
    final existing = widget.transaction;
    if (existing == null) {
      await controller.create(
        TransactionDraft(
          type: _type,
          amountMinor: amountMinor,
          categoryId: _categoryId!,
          occurredOn: _date,
          note: note,
        ),
      );
    } else {
      await controller.edit(
        existing.copyWith(
          type: _type,
          amountMinor: amountMinor,
          categoryId: _categoryId!,
          occurredOn: _date,
          note: note,
        ),
      );
    }
    if (!mounted) return;
    if (!ref.read(transactionFormControllerProvider).hasError) context.pop();
  }

  Future<void> _delete(MoneyTransaction transaction) async {
    final deleted = await confirmAndDeleteTransaction(
      context,
      ref,
      transaction.id,
    );
    if (deleted && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final transaction = widget.transaction;
    final state = ref.watch(transactionFormControllerProvider);
    ref.listen(transactionFormControllerProvider, (_, next) {
      if (next is AsyncError) _onError(next.error);
    });
    final currencyCode = ref.watch(
      settingsControllerProvider.select((s) => s.currencyCode),
    );
    final symbol = NumberFormat.simpleCurrency(
      locale: 'en_US',
      name: currencyCode,
    ).currencySymbol;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editTransaction : l10n.newTransaction),
        actions: [
          if (transaction != null)
            IconButton(
              key: const Key('tx-delete'),
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: state.isLoading ? null : () => _delete(transaction),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text(l10n.expense, key: const Key('tx-type-expense')),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text(l10n.income, key: const Key('tx-type-income')),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                if (s.first == _type) return;
                _type = s.first;
                // The selected category belonged to the previous type.
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 24),
            Semantics(
              identifier: 'tx-amount',
              child: TextField(
                key: const Key('tx-amount'),
                controller: _amount,
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
                  labelText: l10n.amount,
                  prefixText: '$symbol ',
                  errorText: _errorFor('amount'),
                ),
                onChanged: (_) => _clearError('amount'),
              ),
            ),
            const SizedBox(height: 24),
            Text(l10n.category, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _CategoryPicker(
              type: _type,
              originalCategoryId: transaction?.type == _type
                  ? transaction?.categoryId
                  : null,
              selectedId: _categoryId,
              onSelected: (id) => setState(() {
                _categoryId = id;
                _errors = {..._errors}..remove('category');
              }),
            ),
            if (_errors.containsKey('category'))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _errorFor('category')!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ListTile(
              key: const Key('tx-date'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(l10n.date),
              subtitle: Text(
                DateFormat(
                  'EEE, MMM d, y',
                  'en_US',
                ).format(_date.toDateTime()),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('tx-note'),
              controller: _note,
              maxLength: maxNoteLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.note,
                hintText: l10n.noteHint,
                errorText: _errorFor('note'),
              ),
              onChanged: (_) => _clearError('note'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                identifier: 'tx-save',
                child: FilledButton(
                  key: const Key('tx-save'),
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
          ],
        ),
      ),
    );
  }
}

class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({
    required this.type,
    required this.selectedId,
    required this.onSelected,
    this.originalCategoryId,
  });

  final TransactionType type;

  /// Category of the transaction being edited (may be archived, so it is
  /// offered even though it is not active).
  final String? originalCategoryId;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final original = originalCategoryId;
    return AsyncStateView<List<Category>>(
      value: ref.watch(activeCategoriesOfTypeProvider(type)),
      onRetry: () => ref.invalidate(categoriesProvider),
      loading: const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(),
      ),
      data: (active) {
        final options = [...active];
        if (original != null && !options.any((c) => c.id == original)) {
          final archived = ref.watch(categoryByIdProvider(original)).value;
          if (archived != null && archived.type == type) {
            options.add(archived);
          }
        }
        if (options.isEmpty) {
          return Row(
            children: [
              Expanded(child: Text(l10n.noCategoriesOfType)),
              TextButton(
                key: const Key('tx-create-category'),
                onPressed: () =>
                    context.push('${Routes.categoryNew}?type=${type.name}'),
                child: Text(l10n.createCategory),
              ),
            ],
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in options)
              Semantics(
                identifier: 'tx-category-${c.name.toLowerCase()}',
                child: ChoiceChip(
                  key: Key('tx-category-${c.id}'),
                  avatar: CategoryAvatar(
                    icon: c.icon,
                    color: c.color,
                    size: 24,
                  ),
                  label: Text(c.name),
                  showCheckmark: false,
                  selected: c.id == selectedId,
                  onSelected: (_) => onSelected(c.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

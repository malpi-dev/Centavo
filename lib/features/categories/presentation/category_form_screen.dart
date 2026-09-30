import 'package:centavo/core/domain/category_palette.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/core/presentation/async_state_view.dart';
import 'package:centavo/core/presentation/category_avatar.dart';
import 'package:centavo/core/presentation/category_icons.dart';
import 'package:centavo/core/presentation/empty_state.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/theme/centavo_colors.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/domain/category_validator.dart';
import 'package:centavo/features/categories/domain/delete_or_archive_category.dart';
import 'package:centavo/features/categories/presentation/categories_providers.dart';
import 'package:centavo/features/categories/presentation/category_form_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Create ([id] null) or edit a category.
class CategoryFormScreen extends ConsumerWidget {
  const CategoryFormScreen({this.id, this.initialType, super.key});

  final String? id;
  final TransactionType? initialType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = this.id;
    if (id == null) {
      return _CategoryForm(
        initialType: initialType ?? TransactionType.expense,
      );
    }
    final l10n = context.l10n;
    return AsyncStateView<Category?>(
      value: ref.watch(categoryByIdProvider(id)),
      onRetry: () => ref.invalidate(categoryByIdProvider(id)),
      loading: Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      data: (category) {
        if (category == null) {
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
        return _CategoryForm(category: category);
      },
    );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({this.category, this.initialType});

  final Category? category;
  final TransactionType? initialType;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.category?.name ?? '',
  );
  late TransactionType _type =
      widget.category?.type ?? widget.initialType ?? TransactionType.expense;
  late String _icon = widget.category?.icon ?? 'other';
  late int _color = widget.category?.color ?? categoryColorPalette.first;
  Map<String, ValidationReason> _errors = {};
  String? _duplicateName;

  bool get _isEditing => widget.category != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _nameError() {
    final l10n = context.l10n;
    if (_duplicateName != null) return _duplicateName;
    final reason = _errors['name'];
    return reason == null ? null : validationMessage(reason, l10n);
  }

  void _onError(Object error) {
    final l10n = context.l10n;
    switch (error) {
      case ValidationError(:final field, :final reason):
        setState(() => _errors = {..._errors, field: reason});
      case DuplicateError():
        setState(() => _duplicateName = l10n.errorDuplicate);
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageFor(error, l10n))));
    }
  }

  Future<void> _save() async {
    final errors = validateCategoryForm(
      name: _name.text,
      icon: _icon,
      color: _color,
    );
    setState(() {
      _errors = errors;
      _duplicateName = null;
    });
    if (errors.isNotEmpty) return;
    final controller = ref.read(categoryFormControllerProvider.notifier);
    final category = widget.category;
    if (category == null) {
      await controller.create(
        name: _name.text,
        type: _type,
        icon: _icon,
        color: _color,
      );
    } else {
      await controller.edit(
        category.copyWith(
          name: normalizeCategoryName(_name.text),
          icon: _icon,
          color: _color,
        ),
      );
    }
    _popIfSucceeded();
  }

  void _popIfSucceeded() {
    if (!mounted) return;
    if (!ref.read(categoryFormControllerProvider).hasError) context.pop();
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _toggleArchive(Category category) async {
    final l10n = context.l10n;
    final controller = ref.read(categoryFormControllerProvider.notifier);
    if (category.isArchived) {
      await controller.unarchive(category.id);
    } else {
      await controller.archive(category.id);
    }
    if (!mounted || ref.read(categoryFormControllerProvider).hasError) return;
    final message = category.isArchived
        ? l10n.categoryUnarchived
        : l10n.categoryArchived;
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _delete(Category category) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCategoryTitle),
        content: Text(l10n.deleteCategoryMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('category-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref
        .read(categoryFormControllerProvider.notifier)
        .remove(category.id);
    if (!mounted || result == null) return;
    final message = switch (result) {
      CategoryRemoval.deleted => l10n.categoryDeleted,
      CategoryRemoval.archived => l10n.categoryArchivedInUse,
    };
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final category = widget.category;
    final state = ref.watch(categoryFormControllerProvider);
    ref.listen(categoryFormControllerProvider, (_, next) {
      if (next is AsyncError) _onError(next.error);
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editCategory : l10n.newCategory),
        actions: [
          if (category != null)
            PopupMenuButton<String>(
              key: const Key('category-menu'),
              enabled: !state.isLoading,
              onSelected: (value) => value == 'delete'
                  ? _delete(category)
                  : _toggleArchive(category),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const Key('category-archive'),
                  value: 'archive',
                  child: Text(
                    category.isArchived ? l10n.unarchive : l10n.archive,
                  ),
                ),
                PopupMenuItem(
                  key: const Key('category-delete'),
                  value: 'delete',
                  child: Text(l10n.delete),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CategoryAvatar(icon: _icon, color: _color, size: 64),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('category-name'),
              controller: _name,
              maxLength: maxCategoryNameLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.categoryName,
                errorText: _nameError(),
              ),
              onChanged: (_) {
                if (_duplicateName != null || _errors.containsKey('name')) {
                  setState(() {
                    _duplicateName = null;
                    _errors = {..._errors}..remove('name');
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Text(l10n.categoryType, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<TransactionType>(
              key: const Key('category-type'),
              segments: [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text(l10n.expense),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text(l10n.income),
                ),
              ],
              selected: {_type},
              onSelectionChanged: _isEditing
                  ? null
                  : (s) => setState(() => _type = s.first),
            ),
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.typeCannotChange,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(l10n.categoryIcon, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in categoryIconKeys)
                  _IconChoice(
                    key: Key('category-icon-$key'),
                    iconKey: key,
                    selected: key == _icon,
                    onTap: () => setState(() => _icon = key),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l10n.categoryColor, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < categoryColorPalette.length; i++)
                  _ColorChoice(
                    key: Key('category-color-$i'),
                    color: categoryColorPalette[i],
                    selected: categoryColorPalette[i] == _color,
                    onTap: () =>
                        setState(() => _color = categoryColorPalette[i]),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('category-save'),
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
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.iconKey,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String iconKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? scheme.primaryContainer : null,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Icon(
          categoryIcon(iconKey),
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final int color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = context.colors.category(color);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(shape: BoxShape.circle, color: resolved),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}

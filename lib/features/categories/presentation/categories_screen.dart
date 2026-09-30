import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/presentation/async_state_view.dart';
import 'package:centavo/core/presentation/category_avatar.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/presentation/categories_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categoriesTitle),
        actions: [
          PopupMenuButton<TransactionType>(
            key: const Key('categories-add'),
            icon: const Icon(Icons.add),
            tooltip: l10n.addCategory,
            onSelected: (type) =>
                context.push('${Routes.categoryNew}?type=${type.name}'),
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const Key('categories-add-expense'),
                value: TransactionType.expense,
                child: Text(l10n.expenseCategory),
              ),
              PopupMenuItem(
                key: const Key('categories-add-income'),
                value: TransactionType.income,
                child: Text(l10n.incomeCategory),
              ),
            ],
          ),
        ],
      ),
      body: AsyncStateView<List<Category>>(
        value: ref.watch(categoriesProvider),
        onRetry: () => ref.invalidate(categoriesProvider),
        data: (all) {
          final expenses = all
              .where((c) => c.isActive && c.type == TransactionType.expense)
              .toList();
          final income = all
              .where((c) => c.isActive && c.type == TransactionType.income)
              .toList();
          final archived = all.where((c) => c.isArchived).toList();
          return ListView(
            children: [
              _Section(title: l10n.sectionExpenses, categories: expenses),
              _Section(title: l10n.sectionIncome, categories: income),
              if (archived.isNotEmpty)
                _Section(title: l10n.sectionArchived, categories: archived),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.categories});

  final String title;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        for (final c in categories) _CategoryTile(category: c),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: Key('category-${category.id}'),
      leading: CategoryAvatar(icon: category.icon, color: category.color),
      title: Text(category.name),
      trailing: category.isDefault
          ? Chip(
              label: Text(context.l10n.defaultBadge),
              visualDensity: VisualDensity.compact,
              labelStyle: theme.textTheme.labelSmall,
            )
          : null,
      onTap: () => context.push(Routes.categoryEdit(category.id)),
    );
  }
}

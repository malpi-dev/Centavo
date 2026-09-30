import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'categories_providers.g.dart';

@riverpod
Stream<List<Category>> categories(Ref ref) =>
    ref.watch(categoryRepositoryProvider).watchAll();

/// Active categories of one type, for pickers (transaction form, budgets).
@riverpod
Future<List<Category>> activeCategoriesOfType(
  Ref ref,
  TransactionType type,
) async {
  final all = await ref.watch(categoriesProvider.future);
  return all.where((c) => c.type == type && c.isActive).toList();
}

@riverpod
Future<Category?> categoryById(Ref ref, String id) =>
    ref.watch(categoryRepositoryProvider).findById(id);

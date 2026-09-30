import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/di/use_case_providers.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/domain/delete_or_archive_category.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_form_controller.g.dart';

@riverpod
class CategoryFormController extends _$CategoryFormController {
  @override
  FutureOr<void> build() {}

  Future<void> create({
    required String name,
    required TransactionType type,
    required String icon,
    required int color,
  }) => _run(
    () => ref
        .read(categoryRepositoryProvider)
        .create(name: name, type: type, icon: icon, color: color),
  );

  Future<void> edit(Category category) =>
      _run(() => ref.read(categoryRepositoryProvider).update(category));

  Future<void> archive(String id) =>
      _run(() => ref.read(categoryRepositoryProvider).archive(id));

  Future<void> unarchive(String id) =>
      _run(() => ref.read(categoryRepositoryProvider).unarchive(id));

  /// Returns the outcome, or null when it failed (state is then `AsyncError`).
  Future<CategoryRemoval?> remove(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(deleteOrArchiveCategoryProvider).call(id),
    );
    state = result.whenData((_) {});
    return result.value;
  }

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
  }
}

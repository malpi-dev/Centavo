import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/di/use_case_providers.dart';
import 'package:centavo/features/export/domain/export_models.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'export_controller.g.dart';

@riverpod
class ExportController extends _$ExportController {
  @override
  FutureOr<void> build() {}

  /// Builds the CSV and opens the share sheet. On failure the state is an
  /// AsyncError holding the ExportError.
  Future<void> export(ExportRange range) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final currency = ref.read(settingsControllerProvider).currencyCode;
      final doc = await ref
          .read(exportTransactionsCsvProvider)
          .call(range, currencyCode: currency);
      await ref.read(csvShareServiceProvider).share(doc);
    });
  }
}

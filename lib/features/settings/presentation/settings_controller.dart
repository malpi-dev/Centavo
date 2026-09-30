import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controller.g.dart';

@Riverpod(keepAlive: true)
class SettingsController extends _$SettingsController {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> change(AppSettings Function(AppSettings current) update) async {
    final next = update(state);
    await ref.read(settingsRepositoryProvider).save(next);
    state = next;
  }
}

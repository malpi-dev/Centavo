import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/app_mode.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_mode_provider.g.dart';

@Riverpod(keepAlive: true)
class AppModeController extends _$AppModeController {
  /// Never persisted (definition section 8.3).
  @override
  AppMode build() => AppMode.local;

  /// Every demo session starts from fresh data and nothing survives it.
  void enterDemo() {
    _resetDemo();
    state = AppMode.demo;
  }

  void exitDemo() {
    state = AppMode.local;
    _resetDemo();
  }

  void _resetDemo() => ref
    ..invalidate(demoDataStoreProvider)
    ..invalidate(demoSettingsRepositoryProvider)
    ..invalidate(demoAuthRepositoryProvider)
    ..invalidate(demoBackupRepositoryProvider);
}

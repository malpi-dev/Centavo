import 'package:centavo/core/domain/app_mode.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_mode_provider.g.dart';

@Riverpod(keepAlive: true)
class AppModeController extends _$AppModeController {
  /// Never persisted (definition section 8.3).
  @override
  AppMode build() => AppMode.local;

  void enterDemo() => state = AppMode.demo;

  void exitDemo() => state = AppMode.local;
}

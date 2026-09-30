import 'package:centavo/core/di/repository_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_providers.g.dart';

/// Whether the device has a screen lock or biometrics configured.
@riverpod
Future<bool> deviceSecure(Ref ref) =>
    ref.watch(biometricRepositoryProvider).isDeviceSecure();

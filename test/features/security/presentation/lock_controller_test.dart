import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/security/data/mock_biometric_repository.dart';
import 'package:centavo/features/security/data/noop_secure_window_service.dart';
import 'package:centavo/features/security/presentation/lock_controller.dart';
import 'package:centavo/features/settings/data/in_memory_settings_repository.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FixedClock clock;
  late MockBiometricRepository biometric;
  late NoopSecureWindowService secureWindow;

  ProviderContainer make({bool lockEnabled = true}) {
    clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
    biometric = MockBiometricRepository();
    secureWindow = NoopSecureWindowService();
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          InMemorySettingsRepository(
            AppSettings(
              onboardingCompleted: true,
              biometricLockEnabled: lockEnabled,
            ),
          ),
        ),
        clockProvider.overrideWithValue(clock),
        biometricRepositoryProvider.overrideWithValue(biometric),
        secureWindowServiceProvider.overrideWithValue(secureWindow),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(TestWidgetsFlutterBinding.ensureInitialized);

  test('cold start with the lock enabled is locked', () {
    final c = make();
    expect(c.read(lockControllerProvider), isTrue);
    expect(secureWindow.lastSecure, isTrue);
  });

  test('cold start with the lock disabled is unlocked', () {
    final c = make(lockEnabled: false);
    expect(c.read(lockControllerProvider), isFalse);
    expect(secureWindow.lastSecure, isFalse);
  });

  test('29 s in background does not lock, 30 s does', () async {
    final c = make();
    await c.read(lockControllerProvider.notifier).unlock('r');
    final notifier = c.read(lockControllerProvider.notifier)..onBackgrounded();
    clock.now = clock.now.add(const Duration(seconds: 29));
    notifier.onForegrounded();
    expect(c.read(lockControllerProvider), isFalse);

    notifier.onBackgrounded();
    clock.now = clock.now.add(const Duration(seconds: 30));
    notifier.onForegrounded();
    expect(c.read(lockControllerProvider), isTrue);
  });

  test('unlock succeeds with the mock', () async {
    final c = make();
    await c.read(lockControllerProvider.notifier).unlock('reason');
    expect(c.read(lockControllerProvider), isFalse);
    expect(biometric.reasons, ['reason']);
  });

  test('cancelled unlock throws and stays locked', () async {
    final c = make();
    biometric.nextError = const BiometricError(BiometricErrorKind.cancelled);
    await expectLater(
      c.read(lockControllerProvider.notifier).unlock('r'),
      throwsA(isA<BiometricError>()),
    );
    expect(c.read(lockControllerProvider), isTrue);
  });

  test('turning the setting off unlocks and clears FLAG_SECURE', () async {
    final c = make();
    expect(c.read(lockControllerProvider), isTrue);
    await c
        .read(settingsControllerProvider.notifier)
        .change((s) => s.copyWith(biometricLockEnabled: false));
    expect(c.read(lockControllerProvider), isFalse);
    expect(secureWindow.lastSecure, isFalse);
  });

  test('turning the setting on sets FLAG_SECURE without locking', () async {
    final c = make(lockEnabled: false)..read(lockControllerProvider);
    await c
        .read(settingsControllerProvider.notifier)
        .change((s) => s.copyWith(biometricLockEnabled: true));
    expect(c.read(lockControllerProvider), isFalse);
    expect(secureWindow.lastSecure, isTrue);
  });

  test('lifecycle events during the system prompt do not re-lock', () async {
    final c = make();
    final notifier = c.read(lockControllerProvider.notifier);
    biometric.nextError = null;
    // Simulate the prompt pausing the app while authentication is running.
    final pending = notifier.confirmIdentity('r');
    notifier.onBackgrounded();
    clock.now = clock.now.add(const Duration(minutes: 5));
    notifier.onForegrounded();
    await pending;
    expect(c.read(lockControllerProvider), isTrue); // untouched by confirm
    await notifier.unlock('r');
    expect(c.read(lockControllerProvider), isFalse);
  });

  test('changing the app mode unlocks', () {
    final c = make();
    expect(c.read(lockControllerProvider), isTrue);
    c.read(appModeControllerProvider.notifier).enterDemo();
    expect(c.read(lockControllerProvider), isFalse);
  });
}

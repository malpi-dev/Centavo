import 'package:centavo/core/domain/app_mode.dart';
import 'package:centavo/core/router/app_redirect.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fresh = AppSettings();
  const onboarded = AppSettings(onboardingCompleted: true);

  test('sends non-onboarded users to welcome', () {
    expect(
      appRedirect(
        location: Routes.dashboard,
        settings: fresh,
        mode: AppMode.local,
      ),
      Routes.welcome,
    );
  });

  test('does not loop on welcome subroutes', () {
    expect(
      appRedirect(
        location: Routes.welcomeCurrency,
        settings: fresh,
        mode: AppMode.local,
      ),
      isNull,
    );
  });

  test('allows restore auth routes without onboarding', () {
    expect(
      appRedirect(
        location: Routes.backupSignIn,
        settings: fresh,
        mode: AppMode.local,
      ),
      isNull,
    );
    expect(
      appRedirect(
        location: Routes.backupVerify,
        settings: fresh,
        mode: AppMode.local,
      ),
      isNull,
    );
  });

  test('sends onboarded users away from welcome', () {
    expect(
      appRedirect(
        location: Routes.welcome,
        settings: onboarded,
        mode: AppMode.local,
      ),
      Routes.dashboard,
    );
  });

  test('demo mode counts as onboarded', () {
    expect(
      appRedirect(
        location: Routes.dashboard,
        settings: fresh,
        mode: AppMode.demo,
      ),
      isNull,
    );
    expect(
      appRedirect(
        location: Routes.welcome,
        settings: fresh,
        mode: AppMode.demo,
      ),
      Routes.dashboard,
    );
  });

  test('onboarded users elsewhere are untouched', () {
    expect(
      appRedirect(
        location: Routes.budgets,
        settings: onboarded,
        mode: AppMode.local,
      ),
      isNull,
    );
  });

  group('lock', () {
    const lockOn = AppSettings(
      onboardingCompleted: true,
      biometricLockEnabled: true,
    );

    test('locked app sends any route to /lock with the origin', () {
      expect(
        appRedirect(
          location: Routes.transactions,
          settings: lockOn,
          mode: AppMode.local,
          isLocked: true,
        ),
        '/lock?from=%2Ftransactions',
      );
    });

    test('keeps the query string of the origin', () {
      expect(
        appRedirect(
          location: Routes.budgetEdit,
          fullLocation: '/budgets/edit?category=c1&month=2026-10',
          settings: lockOn,
          mode: AppMode.local,
          isLocked: true,
        ),
        '/lock?from=${Uri.encodeComponent('/budgets/edit?category=c1&month=2026-10')}',
      );
    });

    test('stays on /lock while locked', () {
      expect(
        appRedirect(
          location: Routes.lock,
          settings: lockOn,
          mode: AppMode.local,
          isLocked: true,
        ),
        isNull,
      );
    });

    test('unlocked /lock returns to from', () {
      expect(
        appRedirect(
          location: Routes.lock,
          lockFrom: '/budgets',
          settings: lockOn,
          mode: AppMode.local,
        ),
        '/budgets',
      );
    });

    test('invalid from falls back to the dashboard', () {
      for (final from in [null, 'https://evil.com', '//evil.com', '/lock']) {
        expect(
          appRedirect(
            location: Routes.lock,
            lockFrom: from,
            settings: lockOn,
            mode: AppMode.local,
          ),
          Routes.dashboard,
        );
      }
    });

    test('lock does not apply before onboarding', () {
      expect(
        appRedirect(
          location: Routes.dashboard,
          settings: fresh,
          mode: AppMode.local,
          isLocked: true,
        ),
        Routes.welcome,
      );
    });
  });
}

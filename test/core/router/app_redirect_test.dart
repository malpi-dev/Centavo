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
}

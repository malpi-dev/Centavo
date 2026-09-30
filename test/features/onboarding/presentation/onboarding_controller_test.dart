import 'package:centavo/core/di/use_case_providers.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/categories/domain/seed_default_categories.dart';
import 'package:centavo/features/onboarding/presentation/onboarding_controller.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_overrides.dart';

class _MockSeed extends Mock implements SeedDefaultCategories {}

void main() {
  test(
    'a failing seed leaves onboarding incomplete and exposes the error',
    () async {
      final seed = _MockSeed();
      when(seed.call).thenThrow(const StorageError());
      final container = ProviderContainer(
        overrides: [
          ...testOverrides(),
          seedDefaultCategoriesProvider.overrideWithValue(seed),
        ],
      );
      addTearDown(container.dispose);
      container.listen(onboardingControllerProvider, (_, _) {});

      await container
          .read(onboardingControllerProvider.notifier)
          .completeFreshStart('MXN');

      final state = container.read(onboardingControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<StorageError>());
      final settings = container.read(settingsControllerProvider);
      expect(settings.onboardingCompleted, isFalse);
      expect(settings.currencyCode, 'USD');
    },
  );
}

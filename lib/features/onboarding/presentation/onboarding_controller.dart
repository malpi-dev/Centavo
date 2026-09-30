import 'package:centavo/core/di/use_case_providers.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_controller.g.dart';

@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  FutureOr<void> build() {}

  /// Categories first, onboarding flag after: if seeding fails the user stays
  /// on the welcome flow and can retry.
  Future<void> completeFreshStart(String currencyCode) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(seedDefaultCategoriesProvider).call();
      await ref
          .read(settingsControllerProvider.notifier)
          .change(
            (s) => s.copyWith(
              currencyCode: currencyCode,
              onboardingCompleted: true,
            ),
          );
    });
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/providers.dart';

/// Tracks whether the user has completed initial onboarding.
class OnboardingController extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(preferencesServiceProvider).isOnboardingCompleted;
  }

  Future<void> completeOnboarding() async {
    await ref.read(preferencesServiceProvider).setOnboardingCompleted(true);
    state = true;
  }

  Future<void> resetOnboarding() async {
    await ref.read(preferencesServiceProvider).setOnboardingCompleted(false);
    state = false;
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);

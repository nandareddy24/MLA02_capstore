import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/providers.dart';
import '../../../dashboard/presentation/controllers/dashboard_controller.dart';

/// Manages configurable application settings exposed on the Profile screen.
class ProfileSettingsController extends Notifier<String> {
  @override
  String build() {
    return ref.watch(apiClientProvider).baseUrl;
  }

  Future<void> saveApiBaseUrl(String url) async {
    await ref.read(preferencesServiceProvider).setApiBaseUrl(url);
    state = ref.read(apiClientProvider).baseUrl;
    ref.invalidate(dashboardControllerProvider);
  }
}

final profileSettingsControllerProvider =
    NotifierProvider<ProfileSettingsController, String>(
  ProfileSettingsController.new,
);

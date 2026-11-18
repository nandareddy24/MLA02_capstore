import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';

enum AuthBannerTone { error, success, info }

/// Inline feedback banner for authentication, OTP, and password reset screens.
class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    super.key,
    required this.message,
    required this.tone,
  });

  final String message;
  final AuthBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final (Color color, Color surface, IconData icon) = switch (tone) {
      AuthBannerTone.error => (
          AppColors.dangerous,
          AppColors.dangerousSurface(brightness),
          LucideIcons.triangleAlert,
        ),
      AuthBannerTone.success => (
          AppColors.safe,
          AppColors.safeSurface(brightness),
          LucideIcons.circleCheck,
        ),
      AuthBannerTone.info => (
          AppColors.information,
          AppColors.informationSurface(brightness),
          LucideIcons.info,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog allowing users to configure the FixWise authentication & API server URL
/// before signing in or registering.
Future<void> showAuthServerConfigDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final formKey = GlobalKey<FormState>();
  final currentUrl = ref.read(profileSettingsControllerProvider);
  final controller = TextEditingController(text: currentUrl);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Authentication Server'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure your FixWise backend API base URL to enable real user authentication, OTP verification, and password recovery.',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: controller,
                  label: 'Backend API Base URL',
                  hint: 'https://api.fixwise.local',
                  prefixIcon: LucideIcons.server,
                  keyboardType: TextInputType.url,
                  validator: Validators.optionalUrl,
                ),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PrimaryButton(
                  label: 'Save URL',
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    await ref
                        .read(profileSettingsControllerProvider.notifier)
                        .saveApiBaseUrl(controller.text);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  controller.dispose();
}

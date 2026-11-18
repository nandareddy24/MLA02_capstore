import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/responsive_layout.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';

/// Full-panel loading screen shown while the fault report is being submitted
/// and evaluated by the FixWise diagnosis backend.
class AnalysisProcessingView extends StatelessWidget {
  const AnalysisProcessingView({
    super.key,
    required this.deviceLabel,
  });

  final String deviceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ResponsiveContentContainer(
        maxWidth: 460,
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLoadingIndicator(),
              Text(
                'Analyzing reported symptoms',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Evaluating structured fault inputs for $deviceLabel through the FixWise diagnosis engine. Please wait...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Honest failure state when backend diagnosis fails or is unavailable.
///
/// Deliberately never displays fabricated diagnostic results and offers
/// idempotent retry, edit, and saved-report navigation.
class AnalysisFailureView extends StatelessWidget {
  const AnalysisFailureView({
    super.key,
    required this.failure,
    required this.onRetry,
    required this.onEditReport,
    this.onViewSavedReport,
  });

  final Failure failure;
  final VoidCallback onRetry;
  final VoidCallback onEditReport;
  final VoidCallback? onViewSavedReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNotIntegrated = failure is ModelNotIntegratedFailure;

    return Center(
      child: SingleChildScrollView(
        child: ResponsiveContentContainer(
          maxWidth: 480,
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isNotIntegrated
                          ? AppColors.warningSurface(theme.brightness)
                          : AppColors.dangerousSurface(theme.brightness),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.buttonRadius,
                      ),
                      border: Border.all(
                        color: (isNotIntegrated
                                ? AppColors.warning
                                : AppColors.dangerous)
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      LucideIcons.triangleAlert,
                      size: AppSpacing.iconLg,
                      color: isNotIntegrated
                          ? AppColors.warning
                          : AppColors.dangerous,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  isNotIntegrated
                      ? 'Diagnosis Service Not Configured'
                      : 'Unable to Complete Analysis',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  failure.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (onViewSavedReport != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your fault report has been saved locally in case history without generating placeholder predictions.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Retry Analysis',
                  icon: LucideIcons.refreshCw,
                  onPressed: onRetry,
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: 'Back to Review',
                  icon: LucideIcons.arrowLeft,
                  onPressed: onEditReport,
                ),
                if (onViewSavedReport != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: onViewSavedReport,
                    child: const Text('View Saved Report'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

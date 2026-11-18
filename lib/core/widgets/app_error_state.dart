import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'secondary_button.dart';

/// Minimalist enterprise error state using semantic danger tokens and retry action.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.title = 'Unable to complete request',
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.icon = LucideIcons.triangleAlert,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.dangerousSurface(theme.brightness),
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  border: Border.all(
                    color: AppColors.dangerous.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  icon,
                  size: AppSpacing.iconLg,
                  color: AppColors.dangerous,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.lg),
                SecondaryButton(
                  label: retryLabel,
                  icon: LucideIcons.refreshCw,
                  onPressed: onRetry,
                  expand: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

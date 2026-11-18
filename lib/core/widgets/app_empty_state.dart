import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'primary_button.dart';

/// Minimalist enterprise empty state with crisp bordered icon frame (no decorative circles).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

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
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Icon(
                  icon,
                  size: AppSpacing.iconLg,
                  color: colorScheme.primary,
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
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: actionLabel!,
                  icon: actionIcon,
                  onPressed: onAction,
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

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// Standardized enterprise confirmation dialog supporting both normal and
/// high-risk destructive actions.
class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDangerous = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDangerous;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDangerous: isDangerous,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.screenHorizontal,
        AppSpacing.screenHorizontal,
        AppSpacing.xs,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xs,
        AppSpacing.screenHorizontal,
        AppSpacing.md,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        AppSpacing.screenHorizontal,
      ),
      title: Row(
        children: [
          if (isDangerous) ...[
            const Icon(
              LucideIcons.triangleAlert,
              size: AppSpacing.iconMd,
              color: AppColors.dangerous,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
        ],
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: cancelLabel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PrimaryButton(
                label: confirmLabel,
                isDangerous: isDangerous,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

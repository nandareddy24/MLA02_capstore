import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum BadgeTone { neutral, info, safe, warning, dangerous }

/// Compact semantic status indicator using FixWise's exact status color palette.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final (Color bg, Color fg, Color border) = switch (tone) {
      BadgeTone.neutral => (
          theme.colorScheme.surfaceContainer,
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.outline,
        ),
      BadgeTone.info => (
          AppColors.informationSurface(brightness),
          AppColors.information,
          AppColors.information.withValues(alpha: 0.25),
        ),
      BadgeTone.safe => (
          AppColors.safeSurface(brightness),
          AppColors.safe,
          AppColors.safe.withValues(alpha: 0.25),
        ),
      BadgeTone.warning => (
          AppColors.warningSurface(brightness),
          AppColors.warning,
          AppColors.warning.withValues(alpha: 0.28),
        ),
      BadgeTone.dangerous => (
          AppColors.dangerousSurface(brightness),
          AppColors.dangerous,
          AppColors.dangerous.withValues(alpha: 0.28),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

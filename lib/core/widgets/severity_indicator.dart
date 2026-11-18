import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/fault_report_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Semantic severity indicator mapping [FaultSeverity] to exact FixWise status colors.
class SeverityIndicator extends StatelessWidget {
  const SeverityIndicator({
    super.key,
    required this.severity,
    this.showPrefix = false,
  });

  final FaultSeverity severity;
  final bool showPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final (Color color, Color surface, IconData icon) = switch (severity) {
      FaultSeverity.low => (
          AppColors.safe,
          AppColors.safeSurface(brightness),
          LucideIcons.circleCheck,
        ),
      FaultSeverity.medium => (
          AppColors.information,
          AppColors.informationSurface(brightness),
          LucideIcons.info,
        ),
      FaultSeverity.high => (
          AppColors.warning,
          AppColors.warningSurface(brightness),
          LucideIcons.triangleAlert,
        ),
      FaultSeverity.critical => (
          AppColors.dangerous,
          AppColors.dangerousSurface(brightness),
          LucideIcons.octagonAlert,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xxs + 2),
          Text(
            showPrefix ? 'Severity: ${severity.label}' : severity.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

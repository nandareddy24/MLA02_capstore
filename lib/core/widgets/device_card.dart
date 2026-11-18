import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/device_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';
import 'status_badge.dart';

/// Standardized enterprise device inventory card with clear metadata hierarchy.
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    this.onDelete,
  });

  final DeviceModel device;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  IconData get _categoryIcon => switch (device.category) {
        DeviceCategory.hvac => LucideIcons.thermometer,
        DeviceCategory.electrical => LucideIcons.zap,
        DeviceCategory.industrial => LucideIcons.cog,
        DeviceCategory.computing => LucideIcons.smartphone,
        DeviceCategory.automotive => LucideIcons.gauge,
        DeviceCategory.appliance => LucideIcons.cpu,
        DeviceCategory.other => LucideIcons.hardDrive,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySurface(theme.brightness),
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.8),
              ),
            ),
            child: Icon(
              _categoryIcon,
              size: AppSpacing.iconMd,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${device.manufacturer} • ${device.modelNumber}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    StatusBadge(
                      label: device.category.label,
                      tone: BadgeTone.info,
                    ),
                    if (device.location != null)
                      StatusBadge(
                        label: device.location!,
                        icon: LucideIcons.mapPin,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onDelete != null)
                IconButton(
                  tooltip: 'Remove device',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(
                    LucideIcons.trash2,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              Icon(
                LucideIcons.chevronRight,
                size: AppSpacing.iconSm,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

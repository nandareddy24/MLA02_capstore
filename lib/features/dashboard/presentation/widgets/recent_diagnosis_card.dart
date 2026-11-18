import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/severity_indicator.dart';
import '../../../../data/repositories/diagnosis_repository.dart';

/// Displays a real completed diagnosis summary record on the Home Dashboard.
class RecentDiagnosisCard extends StatelessWidget {
  const RecentDiagnosisCard({
    super.key,
    required this.record,
    required this.onViewDetails,
  });

  final RecentDiagnosisRecord record;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onViewDetails,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface(theme.brightness),
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                ),
                child: Icon(
                  LucideIcons.smartphone,
                  size: AppSpacing.iconSm,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.deviceName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormatter.formatShortDate(record.diagnosedAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              SeverityIndicator(severity: record.severity),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            record.predictedFault,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'View details',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: AppSpacing.iconSm,
                color: colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Prominent primary diagnostic call-to-action card on the FixWise Home Dashboard.
///
/// Styled in solid FixWise Primary Dark Teal (`#123B46`) with crisp white typography
/// and a high-contrast white CTA button (`Start Diagnosis`).
class DiagnoseActionCard extends StatelessWidget {
  const DiagnoseActionCard({
    super.key,
    required this.onStartDiagnosis,
  });

  final VoidCallback onStartDiagnosis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                ),
                child: const Icon(
                  LucideIcons.activity,
                  size: AppSpacing.iconSm,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Diagnose a Device',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Report device symptoms to identify possible faults and recommended actions.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.primaryButtonHeight,
            child: FilledButton(
              onPressed: onStartDiagnosis,
              style: FilledButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                ),
                textStyle: theme.textTheme.labelLarge,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Start Diagnosis',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Icon(LucideIcons.arrowRight, size: AppSpacing.iconSm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

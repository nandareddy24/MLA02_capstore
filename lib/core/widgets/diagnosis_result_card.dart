import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/diagnosis_result_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utilities/date_formatter.dart';
import 'app_card.dart';
import 'severity_indicator.dart';
import 'status_badge.dart';

/// Primary diagnosis result card displaying verified ML output returned by the
/// Python diagnosis service.
///
/// Only renders a probability/confidence figure when calibrated and supported,
/// and never presents confidence as guaranteed diagnostic accuracy.
class DiagnosisResultCard extends StatelessWidget {
  const DiagnosisResultCard({
    super.key,
    required this.diagnosis,
    this.fallbackDeviceName,
  });

  final DiagnosisResultModel diagnosis;
  final String? fallbackDeviceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceLabel = diagnosis.deviceName ?? fallbackDeviceName ?? 'Device';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                label: 'Most Probable Fault',
                tone: BadgeTone.info,
                icon: LucideIcons.activity,
              ),
              SeverityIndicator(
                severity: diagnosis.severity,
                showPrefix: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            diagnosis.primaryFault,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$deviceLabel • ${DateFormatter.formatDateTime(diagnosis.analyzedAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (diagnosis.hasCalibratedConfidence) ...[
            _CalibratedLikelihoodBar(confidence: diagnosis.confidence!),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.info,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Calibrated probability score is not available for this model artifact.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            diagnosis.summary,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xxs,
            children: [
              Text(
                'Model ${diagnosis.modelVersion}',
                style: theme.textTheme.bodySmall,
              ),
              if (diagnosis.algorithm != null)
                Text(
                  '• ${diagnosis.algorithm}',
                  style: theme.textTheme.bodySmall,
                ),
              if (diagnosis.processingTimeMs != null)
                Text(
                  '• ${diagnosis.processingTimeMs!.toStringAsFixed(1)} ms',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalibratedLikelihoodBar extends StatelessWidget {
  const _CalibratedLikelihoodBar({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percentText = '${(confidence * 100).toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Estimated Likelihood (not guaranteed accuracy)',
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              percentText,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: confidence.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHigh,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

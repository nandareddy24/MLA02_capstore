import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/recommendation_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';
import 'status_badge.dart';

/// Displays an actionable maintenance recommendation returned by the reviewed
/// FixWise decision-support knowledge base.
///
/// Includes step number, action title, clear instructions, risk indicator, and
/// a manual completion checkbox exclusively for safe, low-risk steps (never
/// automatically marked completed).
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.stepNumber,
    required this.recommendation,
    this.isCompleted = false,
    this.onCompletedChanged,
  });

  final int stepNumber;
  final RecommendationModel recommendation;
  final bool isCompleted;
  final ValueChanged<bool>? onCompletedChanged;

  BadgeTone get _riskTone {
    return switch (recommendation.riskLevel) {
      RecommendationRiskLevel.safe => BadgeTone.safe,
      RecommendationRiskLevel.caution => BadgeTone.warning,
      RecommendationRiskLevel.high => BadgeTone.dangerous,
    };
  }

  IconData get _riskIcon {
    return switch (recommendation.riskLevel) {
      RecommendationRiskLevel.safe => LucideIcons.circleCheck,
      RecommendationRiskLevel.caution => LucideIcons.triangleAlert,
      RecommendationRiskLevel.high => LucideIcons.octagonAlert,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showCheckbox =
        recommendation.isCheckable && onCompletedChanged != null;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: isCompleted
          ? AppColors.safe.withValues(alpha: 0.45)
          : recommendation.riskLevel == RecommendationRiskLevel.high
              ? AppColors.dangerous.withValues(alpha: 0.4)
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.safeSurface(theme.brightness)
                      : AppColors.primarySurface(theme.brightness),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: isCompleted
                    ? const Icon(
                        LucideIcons.check,
                        size: 16,
                        color: AppColors.safe,
                      )
                    : Text(
                        '$stepNumber',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        StatusBadge(
                          label: recommendation.riskLevel.label,
                          tone: _riskTone,
                          icon: _riskIcon,
                        ),
                        if (recommendation.estimatedMinutes != null)
                          StatusBadge(
                            label: '~${recommendation.estimatedMinutes} min',
                            icon: LucideIcons.clock,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (showCheckbox) ...[
                const SizedBox(width: AppSpacing.xs),
                Semantics(
                  label: 'Mark step $stepNumber completed',
                  child: Checkbox(
                    value: isCompleted,
                    onChanged: (value) =>
                        onCompletedChanged?.call(value ?? false),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            recommendation.description,
            style: theme.textTheme.bodyMedium,
          ),
          if (recommendation.safetyNote != null &&
              recommendation.safetyNote!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warningSurface(theme.brightness),
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.triangleAlert,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      recommendation.safetyNote!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (recommendation.requiredTools.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: recommendation.requiredTools
                  .map(
                    (tool) => StatusBadge(
                      label: tool,
                      icon: LucideIcons.wrench,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

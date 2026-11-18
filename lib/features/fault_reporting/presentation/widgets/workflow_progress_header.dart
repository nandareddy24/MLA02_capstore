import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Compact mobile-friendly 4-step progress header showing clear step progress
/// and upcoming context without cramped horizontal stepper labels.
class WorkflowProgressHeader extends StatelessWidget {
  const WorkflowProgressHeader({
    super.key,
    required this.currentStep,
  });

  final int currentStep;

  static const List<String> _stepTitles = [
    'Select Device',
    'Select Symptoms',
    'Additional Information',
    'Review & Submit',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stepNumber = currentStep + 1;
    final totalSteps = _stepTitles.length;
    final title = _stepTitles[currentStep.clamp(0, totalSteps - 1)];
    final nextLabel = currentStep < totalSteps - 1
        ? 'Next: ${_stepTitles[currentStep + 1]}'
        : 'Final step before analysis';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outline, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: stepNumber / totalSteps,
                      strokeWidth: 3.5,
                      backgroundColor: colorScheme.outline,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                    Text(
                      '$stepNumber/$totalSteps',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      nextLabel,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List.generate(totalSteps, (index) {
              final active = index <= currentStep;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index < totalSteps - 1 ? 6 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? (index == currentStep
                            ? colorScheme.primary
                            : AppColors.secondary)
                        : colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

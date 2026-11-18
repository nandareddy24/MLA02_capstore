import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../controllers/fault_report_controller.dart';

/// Step 4: Pre-submission summary allowing users to review and edit any section
/// before submitting structured fault data to the diagnosis backend.
class StepReviewSubmit extends StatelessWidget {
  const StepReviewSubmit({
    super.key,
    required this.state,
    required this.onEditStep,
  });

  final FaultReportingWorkflowState state;
  final ValueChanged<int> onEditStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symptoms = state.resolvedSelectedSymptoms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Review & Submit', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Verify your device details and observed symptoms before requesting analysis.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.contentVertical),
        _ReviewSectionCard(
          title: 'Device Information',
          icon: LucideIcons.smartphone,
          onEdit: () => onEditStep(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                label: 'Category',
                value: state.selectedCategory?.name ?? 'Not selected',
              ),
              if (state.manufacturer.trim().isNotEmpty)
                _DetailRow(
                  label: 'Manufacturer',
                  value: state.manufacturer.trim(),
                ),
              if (state.modelName.trim().isNotEmpty)
                _DetailRow(
                  label: 'Model',
                  value: state.modelName.trim(),
                ),
              if (state.deviceAge != null)
                _DetailRow(label: 'Device Age', value: state.deviceAge!),
              if (state.operatingEnvironment != null)
                _DetailRow(
                  label: 'Environment',
                  value: state.operatingEnvironment!,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ReviewSectionCard(
          title: 'Selected Symptoms (${symptoms.length})',
          icon: LucideIcons.activity,
          onEdit: () => onEditStep(1),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: symptoms
                .map(
                  (item) => StatusBadge(
                    label: item.label,
                    tone: BadgeTone.info,
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ReviewSectionCard(
          title: 'Additional Information',
          icon: LucideIcons.fileText,
          onEdit: () => onEditStep(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                label: 'Error Code',
                value: state.errorCode.trim().isEmpty
                    ? 'None provided'
                    : state.errorCode.trim(),
              ),
              _DetailRow(
                label: 'Problem Started',
                value: state.startedWhen ?? 'Not specified',
              ),
              if (state.operatingConditions.trim().isNotEmpty)
                _DetailRow(
                  label: 'Operating Conditions',
                  value: state.operatingConditions.trim(),
                ),
              _DetailRow(
                label: 'Description',
                value: state.problemDescription.trim().isEmpty
                    ? 'No additional description provided.'
                    : state.problemDescription.trim(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewSectionCard extends StatelessWidget {
  const _ReviewSectionCard({
    required this.title,
    required this.icon,
    required this.onEdit,
    required this.child,
  });

  final String title;
  final IconData icon;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: AppSpacing.iconSm, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.pencil, size: 15),
                label: const Text('Edit'),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

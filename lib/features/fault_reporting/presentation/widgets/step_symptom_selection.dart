import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/symptom_chip.dart';
import '../controllers/fault_report_controller.dart';

/// Step 2: Searchable, categorized multi-symptom selection backed by the structured
/// diagnostic catalog for the selected device category.
class StepSymptomSelection extends StatefulWidget {
  const StepSymptomSelection({
    super.key,
    required this.state,
    required this.onToggleSymptom,
    required this.onRemoveSymptom,
    required this.onClearAll,
  });

  final FaultReportingWorkflowState state;
  final ValueChanged<String> onToggleSymptom;
  final ValueChanged<String> onRemoveSymptom;
  final VoidCallback onClearAll;

  @override
  State<StepSymptomSelection> createState() => _StepSymptomSelectionState();
}

class _StepSymptomSelectionState extends State<StepSymptomSelection> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final category = widget.state.selectedCategory;
    if (category == null) return const SizedBox.shrink();

    final selectedItems = widget.state.resolvedSelectedSymptoms;
    final query = _searchCtrl.text.trim().toLowerCase();

    final filteredGroups = category.symptomGroups
        .map((group) {
          if (query.isEmpty) return group;
          final matching = group.symptoms
              .where(
                (s) =>
                    s.label.toLowerCase().contains(query) ||
                    group.name.toLowerCase().contains(query),
              )
              .toList();
          return matching.isEmpty
              ? null
              : (name: group.name, symptoms: matching);
        })
        .where((g) => g != null)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Describe the Problem', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Select all symptoms observed on your ${category.name.toLowerCase()}.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.contentVertical),
        AppTextField(
          controller: _searchCtrl,
          label: 'Search Symptoms',
          hint: 'Filter symptoms (e.g., overheating, no power, noise)',
          prefixIcon: LucideIcons.search,
          onChanged: (_) => setState(() {}),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                  icon: const Icon(LucideIcons.x, size: AppSpacing.iconSm),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Selected Symptoms',
                    style: theme.textTheme.titleSmall,
                  ),
                  StatusBadge(
                    label: '${selectedItems.length} selected',
                    tone: selectedItems.isEmpty
                        ? BadgeTone.neutral
                        : BadgeTone.info,
                  ),
                  if (selectedItems.isNotEmpty)
                    TextButton(
                      onPressed: widget.onClearAll,
                      child: const Text('Clear all'),
                    ),
                ],
              ),
              if (selectedItems.isEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'No symptoms selected yet. Choose at least one symptom below.',
                  style: theme.textTheme.bodySmall,
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: selectedItems.map((symptom) {
                    return Container(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.sm,
                        right: AppSpacing.xxs,
                        top: AppSpacing.xxs,
                        bottom: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface(theme.brightness),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.inputRadius,
                        ),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              symptom.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => widget.onRemoveSymptom(symptom.id),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                LucideIcons.x,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (filteredGroups.isEmpty)
          AppCard(
            child: AppEmptyState(
              icon: LucideIcons.searchX,
              title: 'No matching symptoms',
              message:
                  'Try a different keyword or clear the search box to view all ${category.name} symptoms.',
              actionLabel: 'Clear Search',
              onAction: () {
                _searchCtrl.clear();
                setState(() {});
              },
            ),
          )
        else
          ...category.symptomGroups.map((group) {
            final matching = query.isEmpty
                ? group.symptoms
                : group.symptoms
                    .where(
                      (s) =>
                          s.label.toLowerCase().contains(query) ||
                          group.name.toLowerCase().contains(query),
                    )
                    .toList();
            if (matching.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: matching.map((symptom) {
                        final selected =
                            widget.state.selectedSymptomIds.contains(symptom.id);
                        return SymptomChip(
                          label: symptom.label,
                          selected: selected,
                          onSelected: (_) => widget.onToggleSymptom(symptom.id),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

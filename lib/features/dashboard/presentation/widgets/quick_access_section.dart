import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

/// Three compact quick-access action cards for core FixWise workflows.
class QuickAccessSection extends StatelessWidget {
  const QuickAccessSection({
    super.key,
    required this.onNewDiagnosis,
    required this.onHistory,
    required this.onHelpGuidance,
  });

  final VoidCallback onNewDiagnosis;
  final VoidCallback onHistory;
  final VoidCallback onHelpGuidance;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        label: 'New Diagnosis',
        icon: LucideIcons.activity,
        onTap: onNewDiagnosis,
      ),
      _QuickActionData(
        label: 'Diagnosis History',
        icon: LucideIcons.history,
        onTap: onHistory,
      ),
      _QuickActionData(
        label: 'Help & Guidance',
        icon: LucideIcons.lifeBuoy,
        onTap: onHelpGuidance,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 310;
        if (isVeryNarrow) {
          return Column(
            children: actions
                .map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _QuickAccessTile(data: action, horizontal: true),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              Expanded(
                child: _QuickAccessTile(data: actions[i], horizontal: false),
              ),
              if (i < actions.length - 1) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.data,
    required this.horizontal,
  });

  final _QuickActionData data;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final iconBox = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primarySurface(theme.brightness),
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      ),
      child: Icon(
        data.icon,
        size: AppSpacing.iconSm,
        color: colorScheme.primary,
      ),
    );

    if (horizontal) {
      return AppCard(
        onTap: data.onTap,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            iconBox,
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                data.label,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: AppSpacing.iconSm,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      );
    }

    return AppCard(
      onTap: data.onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconBox,
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_spacing.dart';

/// Clean enterprise toggle chip for selecting observed symptoms or filter states.
class SymptomChip extends StatelessWidget {
  const SymptomChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected ? colorScheme.primary : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outline,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onSelected(!selected),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs + 1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(
                  LucideIcons.check,
                  size: 14,
                  color: colorScheme.onPrimary,
                ),
                const SizedBox(width: AppSpacing.xxs + 2),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

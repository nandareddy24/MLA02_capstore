import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/secondary_button.dart';

/// Displays practical diagnostic workflow guidance and safety escalation notes.
Future<void> showHelpGuidanceSheet(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.cardRadius),
      ),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.lifeBuoy,
                    size: AppSpacing.iconMd,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Help & Diagnostic Guidance',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(LucideIcons.x, size: AppSpacing.iconSm),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              const _GuidanceStep(
                icon: LucideIcons.smartphone,
                title: '1. Select Device & Report Symptoms',
                description:
                    'Choose the affected device, select accurate symptoms, and include error codes or operating conditions when visible.',
              ),
              const SizedBox(height: AppSpacing.md),
              const _GuidanceStep(
                icon: LucideIcons.activity,
                title: '2. Review Probable Faults & Severity',
                description:
                    'Inspect the ranked diagnostic result and severity level before performing any physical disassembly or power cycling.',
              ),
              const SizedBox(height: AppSpacing.md),
              const _GuidanceStep(
                icon: LucideIcons.triangleAlert,
                title: '3. Safety & Escalation',
                description:
                    'For high or critical severity faults—especially electrical, thermal, or pressure hazards—follow lockout procedures and escalate to a certified technician.',
              ),
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                label: 'Close',
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _GuidanceStep extends StatelessWidget {
  const _GuidanceStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primarySurface(theme.brightness),
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          ),
          child: Icon(
            icon,
            size: 18,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

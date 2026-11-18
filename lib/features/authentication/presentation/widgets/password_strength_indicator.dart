import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/validators.dart';

/// Displays live password strength feedback and rule compliance during
/// account registration and password reset.
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = Validators.evaluatePasswordStrength(password);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color activeColor = switch (strength.score) {
      0 || 1 || 2 => AppColors.dangerous,
      3 || 4 => AppColors.warning,
      _ => AppColors.safe,
    };

    final int filledSegments = password.isEmpty
        ? 0
        : strength.score <= 2
            ? 1
            : strength.score <= 4
                ? 2
                : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: List.generate(3, (index) {
                  final filled = index < filledSegments;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: filled
                            ? activeColor
                            : colorScheme.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              password.isEmpty ? 'Strength' : strength.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: password.isEmpty
                    ? colorScheme.onSurfaceVariant
                    : activeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xxs,
          children: [
            _RuleItem(label: '8+ chars', passed: strength.hasMinLength),
            _RuleItem(label: 'Uppercase', passed: strength.hasUppercase),
            _RuleItem(label: 'Lowercase', passed: strength.hasLowercase),
            _RuleItem(label: 'Number', passed: strength.hasNumber),
            _RuleItem(label: 'Symbol', passed: strength.hasSpecialChar),
          ],
        ),
      ],
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({
    required this.label,
    required this.passed,
  });

  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = passed ? AppColors.safe : theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          passed ? LucideIcons.circleCheck : LucideIcons.circle,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

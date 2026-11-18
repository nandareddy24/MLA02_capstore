import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_spacing.dart';

/// Standardized FixWise dropdown selector (`54 px` height, `10 px` radius).
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
    this.validator,
    this.hint,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final IconData? prefixIcon;
  final String? Function(T?)? validator;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          validator: validator,
          style: theme.textTheme.bodyMedium,
          icon: Icon(
            LucideIcons.chevronDown,
            size: AppSpacing.iconSm,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          dropdownColor: theme.colorScheme.surface,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: AppSpacing.iconSm)
                : null,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Enterprise text input (`54 px` min height, `10 px` radius, crisp border).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helperText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int maxLines;
  final int? minLines;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

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
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          enabled: enabled,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: AppSpacing.iconSm)
                : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

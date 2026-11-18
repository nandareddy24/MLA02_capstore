import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

enum AppButtonVariant { primary, secondary, text, danger, dangerOutlined }

/// Unified FixWise button facade backed by [PrimaryButton] and [SecondaryButton].
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      AppButtonVariant.primary => PrimaryButton(
          label: label,
          onPressed: onPressed,
          icon: icon,
          isLoading: isLoading,
          expand: expand,
        ),
      AppButtonVariant.secondary => SecondaryButton(
          label: label,
          onPressed: onPressed,
          icon: icon,
          isLoading: isLoading,
          expand: expand,
        ),
      AppButtonVariant.danger => PrimaryButton(
          label: label,
          onPressed: onPressed,
          icon: icon,
          isLoading: isLoading,
          expand: expand,
          isDangerous: true,
        ),
      AppButtonVariant.dangerOutlined => SecondaryButton(
          label: label,
          onPressed: onPressed,
          icon: icon,
          isLoading: isLoading,
          expand: expand,
          isDangerous: true,
        ),
      AppButtonVariant.text => _buildTextButton(context),
    };
  }

  Widget _buildTextButton(BuildContext context) {
    final button = TextButton(
      onPressed: isLoading ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSpacing.iconSm),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// FixWise Secondary Action Button.
///
/// Specifications:
/// - Background: Card white (`#FFFFFF` in light mode)
/// - Border & text: Dark teal (`#123B46`), or red (`#C74747`) when [isDangerous] is true
/// - Height: 48 px, corner radius: 12 px
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.isDangerous = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final bool isDangerous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = isDangerous ? AppColors.dangerous : colorScheme.primary;
    final effectiveOnPressed = isLoading ? null : onPressed;

    final button = OutlinedButton(
      onPressed: effectiveOnPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: colorScheme.surface,
        foregroundColor: accentColor,
        side: BorderSide(
          color: effectiveOnPressed == null
              ? theme.disabledColor
              : accentColor,
          width: 1.25,
        ),
        minimumSize: const Size(0, AppSpacing.secondaryButtonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        textStyle: theme.textTheme.labelLarge,
      ),
      child: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppSpacing.iconSm),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

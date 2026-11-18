import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// FixWise Primary Action Button.
///
/// Specifications:
/// - Background: Dark teal (`#123B46`), or red (`#C74747`) exclusively when [isDangerous] is true
/// - Text: White, 15 px semibold
/// - Height: 52 px, corner radius: 12 px
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
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
    final effectiveOnPressed = isLoading ? null : onPressed;

    final style = isDangerous
        ? FilledButton.styleFrom(
            backgroundColor: AppColors.dangerous,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, AppSpacing.primaryButtonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            textStyle: theme.textTheme.labelLarge,
          )
        : FilledButton.styleFrom(
            minimumSize: const Size(0, AppSpacing.primaryButtonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            textStyle: theme.textTheme.labelLarge,
          );

    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
          );

    final button = FilledButton(
      onPressed: effectiveOnPressed,
      style: style,
      child: child,
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

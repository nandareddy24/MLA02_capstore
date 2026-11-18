import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Clean bordered enterprise card (`14 px` radius, `#FFFFFF` surface, `#E3E9E9` border).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBorder = borderColor ?? theme.colorScheme.outline;

    return Material(
      color: color ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: effectiveBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            )
          : Padding(padding: padding, child: child),
    );
  }
}

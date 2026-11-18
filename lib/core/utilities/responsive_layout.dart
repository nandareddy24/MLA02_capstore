import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Material 3 adaptive window size classes for Android phones, foldables, and tablets.
enum ScreenSizeClass { compact, medium, expanded }

abstract final class AppBreakpoints {
  static const double compactMax = 600;
  static const double mediumMax = 840;
  static const double maxContentWidth = 960;

  static ScreenSizeClass of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compactMax) {
      return ScreenSizeClass.compact;
    }
    if (width < mediumMax) {
      return ScreenSizeClass.medium;
    }
    return ScreenSizeClass.expanded;
  }

  static bool isCompact(BuildContext context) =>
      of(context) == ScreenSizeClass.compact;

  static int gridColumns(BuildContext context) {
    return switch (of(context)) {
      ScreenSizeClass.compact => 1,
      ScreenSizeClass.medium => 2,
      ScreenSizeClass.expanded => 3,
    };
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return switch (of(context)) {
      ScreenSizeClass.compact => const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.contentVertical,
        ),
      ScreenSizeClass.medium => const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      ScreenSizeClass.expanded => const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
    };
  }
}

/// Centers content on wide Android tablets/foldables while maintaining exact
/// 20 px horizontal padding on standard Android phones.
class ResponsiveContentContainer extends StatelessWidget {
  const ResponsiveContentContainer({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? AppBreakpoints.pagePadding(context),
          child: child,
        ),
      ),
    );
  }
}

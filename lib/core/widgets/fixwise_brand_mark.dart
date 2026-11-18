import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Simple, recognizable geometric brand mark for FixWise.
///
/// Uses a solid dark-teal rounded square with a crisp precision diagnostic
/// pulse/check vector — avoiding decorative AI brain imagery or gradients.
class FixWiseBrandMark extends StatelessWidget {
  const FixWiseBrandMark({
    super.key,
    this.size = 40,
    this.showWordmark = false,
    this.showSubtitle = false,
    this.centered = false,
  });

  final double size;
  final bool showWordmark;
  final bool showSubtitle;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final badgeColor = isDark ? AppColors.secondary : AppColors.primary;

    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: CustomPaint(
        painter: _FixWiseMarkPainter(
          strokeColor: Colors.white,
          accentColor: const Color(0xFF7FD1CD),
        ),
      ),
    );

    if (!showWordmark) {
      return mark;
    }

    if (centered) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppConstants.appName,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          if (showSubtitle) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              AppConstants.appTagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppConstants.appName,
              style: theme.textTheme.titleLarge,
            ),
            if (showSubtitle)
              Text(
                AppConstants.appTagline,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ],
    );
  }
}

class _FixWiseMarkPainter extends CustomPainter {
  const _FixWiseMarkPainter({
    required this.strokeColor,
    required this.accentColor,
  });

  final Color strokeColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = (size.width * 0.085).clamp(2.0, 4.5);

    // Subtle precision frame representing technical instrumentation
    final framePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.65;

    final inset = size.width * 0.16;
    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      ),
      Radius.circular(size.width * 0.12),
    );
    canvas.drawRRect(frameRect, framePaint);

    // Clean diagnostic pulse + verification stroke
    final pulsePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.25, size.height * 0.54)
      ..lineTo(size.width * 0.37, size.height * 0.54)
      ..lineTo(size.width * 0.45, size.height * 0.34)
      ..lineTo(size.width * 0.55, size.height * 0.66)
      ..lineTo(size.width * 0.63, size.height * 0.50)
      ..lineTo(size.width * 0.75, size.height * 0.50);

    canvas.drawPath(path, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _FixWiseMarkPainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.accentColor != accentColor;
  }
}

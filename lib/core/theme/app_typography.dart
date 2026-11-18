import 'package:flutter/material.dart';

/// FixWise enterprise typography hierarchy using bundled Inter with Roboto fallback.
///
/// Type scale:
/// - Main page heading (`headlineMedium`): 26 px, semibold
/// - Screen section heading (`titleLarge`): 18 px, semibold
/// - Card title (`titleMedium`): 16 px, medium
/// - Body text (`bodyMedium`): 14 px, regular
/// - Supporting text (`bodySmall`): 12 px, regular
/// - Button text (`labelLarge`): 15 px, semibold
abstract final class AppTypography {
  static const String primaryFontFamily = 'Inter';
  static const List<String> fallbackFonts = ['Roboto'];

  static TextStyle _inter({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required Color color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fallbackFonts,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme buildTextTheme(ColorScheme colorScheme) {
    final primary = colorScheme.onSurface;
    final secondary = colorScheme.onSurfaceVariant;

    return TextTheme(
      // Main page heading: 26 px, semibold
      headlineMedium: _inter(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.4,
        color: primary,
      ),
      // Secondary page heading: 22 px, semibold
      headlineSmall: _inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.3,
        color: primary,
      ),
      // Screen section heading: 18 px, semibold
      titleLarge: _inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.15,
        color: primary,
      ),
      // Card title: 16 px, medium
      titleMedium: _inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: primary,
      ),
      // Subsection / field label: 14 px, semibold
      titleSmall: _inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: primary,
      ),
      // Large body copy: 15 px, regular
      bodyLarge: _inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: primary,
      ),
      // Body text: 14 px, regular
      bodyMedium: _inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: primary,
      ),
      // Supporting text: 12 px, regular
      bodySmall: _inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: secondary,
      ),
      // Button text: 15 px, semibold
      labelLarge: _inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: primary,
      ),
      // Chip / tab label: 13 px, medium
      labelMedium: _inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.25,
        color: primary,
      ),
      // Badge / metadata label: 12 px, medium
      labelSmall: _inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.25,
        color: secondary,
      ),
    );
  }
}

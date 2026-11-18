import 'package:flutter/material.dart';

/// FixWise enterprise color system.
///
/// Strictly adheres to the FixWise brand specification without arbitrary hues
/// or decorative gradients.
abstract final class AppColors {
  // Core brand colors
  static const Color primary = Color(0xFF123B46);
  static const Color secondary = Color(0xFF176B68);

  // Light surfaces & neutrals
  static const Color background = Color(0xFFF5F7F7);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF172B32);
  static const Color secondaryText = Color(0xFF66767B);
  static const Color border = Color(0xFFE3E9E9);
  static const Color disabled = Color(0xFFAAB5B8);
  static const Color subtleSurface = Color(0xFFEDF2F2);

  // Dark surfaces & neutrals (derived cleanly from the primary slate-teal hue)
  static const Color darkBackground = Color(0xFF0E171A);
  static const Color darkCardBackground = Color(0xFF152227);
  static const Color darkPrimaryText = Color(0xFFE9F0F1);
  static const Color darkSecondaryText = Color(0xFF97A8AD);
  static const Color darkBorder = Color(0xFF24373E);
  static const Color darkDisabled = Color(0xFF56686E);
  static const Color darkSubtleSurface = Color(0xFF1B2C32);

  // Semantic status colors
  static const Color safe = Color(0xFF27845B);
  static const Color warning = Color(0xFFC58A27);
  static const Color dangerous = Color(0xFFC74747);
  static const Color information = Color(0xFF3978AD);

  // Subtle semantic containers (derived from exact status hues, low opacity)
  static Color safeSurface(Brightness brightness) => safe.withValues(
        alpha: brightness == Brightness.dark ? 0.18 : 0.10,
      );

  static Color warningSurface(Brightness brightness) => warning.withValues(
        alpha: brightness == Brightness.dark ? 0.18 : 0.11,
      );

  static Color dangerousSurface(Brightness brightness) => dangerous.withValues(
        alpha: brightness == Brightness.dark ? 0.18 : 0.10,
      );

  static Color informationSurface(Brightness brightness) =>
      information.withValues(
        alpha: brightness == Brightness.dark ? 0.18 : 0.10,
      );

  static Color primarySurface(Brightness brightness) =>
      (brightness == Brightness.dark ? secondary : primary).withValues(
        alpha: brightness == Brightness.dark ? 0.22 : 0.08,
      );

  static ColorScheme get lightColorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE3ECEE),
        onPrimaryContainer: primary,
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFE1F0EF),
        onSecondaryContainer: primary,
        tertiary: information,
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFE4EEF7),
        onTertiaryContainer: Color(0xFF1D466A),
        error: dangerous,
        onError: Colors.white,
        errorContainer: Color(0xFFFBEAEA),
        onErrorContainer: Color(0xFF8C2828),
        surface: cardBackground,
        onSurface: primaryText,
        surfaceContainerLowest: cardBackground,
        surfaceContainerLow: background,
        surfaceContainer: subtleSurface,
        surfaceContainerHigh: Color(0xFFE6ECEC),
        surfaceContainerHighest: Color(0xFFDCE4E5),
        onSurfaceVariant: secondaryText,
        outline: border,
        outlineVariant: Color(0xFFEDF1F1),
        shadow: Color(0x14123B46),
        scrim: Color(0x520E171A),
        inverseSurface: primaryText,
        onInverseSurface: cardBackground,
        inversePrimary: Color(0xFF8CC5C2),
      );

  static ColorScheme get darkColorScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF3E9C98),
        onPrimary: Color(0xFF0A1D22),
        primaryContainer: Color(0xFF153B45),
        onPrimaryContainer: Color(0xFFDCEBEC),
        secondary: Color(0xFF5EB5B1),
        onSecondary: Color(0xFF0B2221),
        secondaryContainer: Color(0xFF153D3B),
        onSecondaryContainer: Color(0xFFD6ECEB),
        tertiary: Color(0xFF6EA5D4),
        onTertiary: Color(0xFF0C2133),
        tertiaryContainer: Color(0xFF1A354D),
        onTertiaryContainer: Color(0xFFD8E9F7),
        error: Color(0xFFE06C6C),
        onError: Color(0xFF2B0B0B),
        errorContainer: Color(0xFF471B1B),
        onErrorContainer: Color(0xFFFBDCDC),
        surface: darkCardBackground,
        onSurface: darkPrimaryText,
        surfaceContainerLowest: darkBackground,
        surfaceContainerLow: darkCardBackground,
        surfaceContainer: darkSubtleSurface,
        surfaceContainerHigh: Color(0xFF20333A),
        surfaceContainerHighest: Color(0xFF283E46),
        onSurfaceVariant: darkSecondaryText,
        outline: darkBorder,
        outlineVariant: Color(0xFF1C2C32),
        shadow: Color(0x33000000),
        scrim: Color(0x73000000),
        inverseSurface: darkPrimaryText,
        onInverseSurface: darkBackground,
        inversePrimary: primary,
      );
}

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Global Material 3 design system themes for FixWise (Light & Dark).
abstract final class AppTheme {
  static ThemeData get light => _buildTheme(
        colorScheme: AppColors.lightColorScheme,
        scaffoldBackground: AppColors.background,
        cardColor: AppColors.cardBackground,
        borderColor: AppColors.border,
        disabledColor: AppColors.disabled,
      );

  static ThemeData get dark => _buildTheme(
        colorScheme: AppColors.darkColorScheme,
        scaffoldBackground: AppColors.darkBackground,
        cardColor: AppColors.darkCardBackground,
        borderColor: AppColors.darkBorder,
        disabledColor: AppColors.darkDisabled,
      );

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color borderColor,
    required Color disabledColor,
  }) {
    final textTheme = AppTypography.buildTextTheme(colorScheme);
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      disabledColor: disabledColor,
      textTheme: textTheme,
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: AppSpacing.iconMd,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSpacing.screenHorizontal,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
          size: AppSpacing.iconMd,
        ),
        shape: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        isDense: false,
        constraints: const BoxConstraints(minHeight: AppSpacing.inputHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: disabledColor),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: colorScheme.error),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(
            color: borderColor.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: disabledColor.withValues(alpha: 0.4),
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          minimumSize: const Size(0, AppSpacing.primaryButtonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.sm,
          ),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          backgroundColor: cardColor,
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: disabledColor,
          minimumSize: const Size(0, AppSpacing.secondaryButtonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.sm,
          ),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: colorScheme.primary, width: 1.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: disabledColor,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            ),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: borderColor)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary;
            }
            return cardColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimary;
            }
            return colorScheme.onSurface;
          }),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        selectedColor: colorScheme.primary,
        disabledColor: disabledColor.withValues(alpha: 0.25),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onPrimary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        ),
        side: BorderSide(color: borderColor),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySurface(colorScheme.brightness),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppSpacing.iconMd,
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: cardColor,
        indicatorColor: AppColors.primarySurface(colorScheme.brightness),
        selectedIconTheme: IconThemeData(
          size: AppSpacing.iconMd,
          color: colorScheme.primary,
        ),
        unselectedIconTheme: IconThemeData(
          size: AppSpacing.iconMd,
          color: colorScheme.onSurfaceVariant,
        ),
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelType: NavigationRailLabelType.all,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        highlightElevation: 2,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 2,
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: borderColor),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return isDark ? AppColors.darkSecondaryText : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.secondary;
          }
          return disabledColor.withValues(alpha: 0.45);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 1,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

import 'app_motion.dart';
import 'app_metrics.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(
    fontFamily: AppTypography.bodyFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
    ).copyWith(primary: AppColors.primary, error: AppColors.error),
  );
  // Material paints feedback within each control's own shape and bounds.
  final pointerOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) return Colors.transparent;
    if (states.contains(WidgetState.pressed)) return const Color(0x18000000);
    if (states.contains(WidgetState.hovered)) return const Color(0x10000000);
    return null;
  });
  return base.copyWith(
    hoverColor: const Color(0x10000000),
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        overlayColor: pointerOverlay,
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        shape: const WidgetStatePropertyAll(CircleBorder()),
      ),
    ),
    switchTheme: SwitchThemeData(overlayColor: pointerOverlay),
    sliderTheme: const SliderThemeData(overlayColor: Colors.transparent),
    tabBarTheme: TabBarThemeData(overlayColor: pointerOverlay),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const AppPageTransitionsBuilder(),
      },
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: AppTypography.sectionTitle,
      contentTextStyle: AppTypography.body,
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    textTheme: base.textTheme.copyWith(
      headlineLarge: AppTypography.pageTitle,
      headlineMedium: AppTypography.pageTitle,
      headlineSmall: AppTypography.pageTitle,
      titleLarge: AppTypography.pageTitle,
      titleMedium: AppTypography.inputText,
      titleSmall: AppTypography.fieldLabel,
      bodyLarge: AppTypography.body,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.helper,
      labelLarge: AppTypography.button,
      labelMedium: AppTypography.helper,
      labelSmall: AppTypography.caption,
    ),
    iconTheme: const IconThemeData(
      size: AppMetrics.iconSize,
      color: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      titleTextStyle: AppTypography.pageTitle,
      centerTitle: true,
      foregroundColor: AppColors.textPrimary,
    ),
    checkboxTheme: CheckboxThemeData(
      side: const BorderSide(color: AppColors.primary, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.white,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      overlayColor: pointerOverlay,
    ),
    radioTheme: RadioThemeData(
      overlayColor: pointerOverlay,
      fillColor: const WidgetStatePropertyAll(AppColors.primary),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: false,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppMetrics.cornerRadius),
        ),
        borderSide: BorderSide(color: AppColors.primary),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppMetrics.cornerRadius),
        ),
        borderSide: BorderSide(color: AppColors.primaryTint),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppMetrics.cornerRadius),
        ),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppMetrics.cornerRadius),
        ),
        borderSide: BorderSide(color: AppColors.error),
      ),
      labelStyle: AppTypography.fieldLabel,
      floatingLabelStyle: AppTypography.fieldLabel,
      hintStyle: AppTypography.helper,
      helperStyle: AppTypography.helper,
      errorStyle: AppTypography.requirement,
      counterStyle: AppTypography.caption,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppMetrics.cornerRadius),
        ),
        borderSide: BorderSide(color: AppColors.primary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppMetrics.cornerRadius),
        ),
        borderSide: BorderSide(color: AppColors.primary),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, AppMetrics.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.cornerRadius),
        ),
        textStyle: AppTypography.button,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledForegroundColor: AppColors.textSecondary,
      ).copyWith(overlayColor: pointerOverlay),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppMetrics.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.cornerRadius),
        ),
        textStyle: AppTypography.button,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ).copyWith(overlayColor: pointerOverlay),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.primary),
        minimumSize: const Size(0, AppMetrics.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.cornerRadius),
        ),
        textStyle: AppTypography.button,
        foregroundColor: AppColors.primary,
      ).copyWith(overlayColor: pointerOverlay),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, AppMetrics.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.cornerRadius),
        ),
        textStyle: AppTypography.button,
        foregroundColor: AppColors.primary,
      ).copyWith(overlayColor: pointerOverlay),
    ),
  );
}

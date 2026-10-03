import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFFB9470B);
  static const primaryStrong = Color(0xFF923607);
  static const primarySoft = Color(0xFFFBE9DE);
  static const canvas = Color(0xFFFAF8F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF3F0EB);
  static const surfaceHigh = Color(0xFFEDE8E2);
  static const ink = Color(0xFF211F1D);
  static const secondaryInk = Color(0xFF716C66);
  static const outline = Color(0xFFE8E2DC);
  static const success = Color(0xFF3D7654);
  static const successSoft = Color(0xFFE8F3EB);
  static const error = Color(0xFFAF443B);
  static const errorSoft = Color(0xFFF8E9E7);
  static const warning = Color(0xFF8B5A24);
  static const warningSoft = Color(0xFFF8EDDC);
  static const information = Color(0xFF526C7A);
  static const informationSoft = Color(0xFFE9EFF1);

  static const primaryContainer = primarySoft;
  static const successContainer = successSoft;
}

final appTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'PlusJakartaSans',
  scaffoldBackgroundColor: AppColors.canvas,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primarySoft,
    onPrimaryContainer: AppColors.primaryStrong,
    secondary: AppColors.primaryStrong,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.surfaceLow,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.information,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: AppColors.errorSoft,
    onErrorContainer: AppColors.error,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.secondaryInk,
    outline: AppColors.outline,
    outlineVariant: AppColors.outline,
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.35,
      color: AppColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: AppColors.ink),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: AppColors.ink),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.4,
      color: AppColors.secondaryInk,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.canvas,
    foregroundColor: AppColors.ink,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleSpacing: 16,
    titleTextStyle: TextStyle(
      fontFamily: 'PlusJakartaSans',
      color: AppColors.ink,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.outline),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceLow,
    labelStyle: const TextStyle(color: AppColors.secondaryInk),
    hintStyle: const TextStyle(color: AppColors.secondaryInk),
    helperStyle: const TextStyle(color: AppColors.secondaryInk),
    errorStyle: const TextStyle(color: AppColors.error),
    prefixIconColor: AppColors.secondaryInk,
    suffixIconColor: AppColors.secondaryInk,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.surfaceHigh,
      disabledForegroundColor: AppColors.secondaryInk,
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.ink,
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      side: const BorderSide(color: AppColors.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surface,
    selectedColor: AppColors.primarySoft,
    disabledColor: AppColors.surfaceLow,
    side: const BorderSide(color: AppColors.outline),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    labelStyle: const TextStyle(
      color: AppColors.secondaryInk,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    secondaryLabelStyle: const TextStyle(
      color: AppColors.primaryStrong,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    showCheckmark: false,
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primaryStrong
            : AppColors.secondaryInk,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primarySoft
            : AppColors.surface,
      ),
      side: const WidgetStatePropertyAll(BorderSide(color: AppColors.outline)),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    indicatorColor: AppColors.primarySoft,
    height: 72,
    elevation: 0,
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        size: 23,
        color: states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.secondaryInk,
      ),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        color: states.contains(WidgetState.selected)
            ? AppColors.primaryStrong
            : AppColors.secondaryInk,
        fontSize: 11,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w600,
      ),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.outline,
    thickness: 1,
    space: 1,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.ink,
    contentTextStyle: const TextStyle(color: Colors.white),
    actionTextColor: const Color(0xFFFFB887),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primary,
    linearTrackColor: AppColors.primarySoft,
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? Colors.white
          : AppColors.secondaryInk,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.primary
          : AppColors.surfaceHigh,
    ),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
  ),
);

import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFFA33900);
  static const primaryContainer = Color(0xFFCC4900);
  static const success = Color(0xFF006E2D);
  static const successContainer = Color(0xFF7CF994);
  static const error = Color(0xFFBA1A1A);
  static const canvas = Color(0xFFF9F9FF);
  static const surfaceLow = Color(0xFFF1F3FF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFE1E8FD);
  static const ink = Color(0xFF141B2B);
  static const secondaryInk = Color(0xFF5A4138);
  static const outline = Color(0xFFE2BFB2);
}

final appTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'PlusJakartaSans',
  scaffoldBackgroundColor: AppColors.canvas,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: Colors.white,
    secondary: AppColors.success,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.successContainer,
    error: AppColors.error,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    outline: AppColors.outline,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.canvas,
    foregroundColor: AppColors.ink,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontFamily: 'PlusJakartaSans',
      color: AppColors.ink,
      fontSize: 20,
      fontWeight: FontWeight.w800,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0x0F141B2B)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceLow,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Color(0xFFFFDBCE),
    height: 72,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
  ),
);

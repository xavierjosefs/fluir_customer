import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const fontFamily = 'Inter';

  static TextTheme get textTheme => const TextTheme(
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 32,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.navy,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 28,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: AppColors.navy,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.navy,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      height: 1.5,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      height: 1.45,
      color: AppColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
  );

  static TextTheme withColors({
    required Color primary,
    required Color secondary,
  }) {
    final base = textTheme;
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(color: primary),
      headlineMedium: base.headlineMedium?.copyWith(color: primary),
      titleLarge: base.titleLarge?.copyWith(color: primary),
      titleMedium: base.titleMedium?.copyWith(color: primary),
      bodyLarge: base.bodyLarge?.copyWith(color: primary),
      bodyMedium: base.bodyMedium?.copyWith(color: secondary),
      labelLarge: base.labelLarge?.copyWith(color: primary),
    );
  }
}

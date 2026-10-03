import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brandBlue = Color(0xFF2563EB);
  static const brandGreen = Color(0xFF0ACF83);

  /// Accessible variant of [brandGreen] for text and icons on light surfaces,
  /// where the brand green alone does not reach a readable contrast.
  static const brandGreenInk = Color(0xFF07734A);

  /// Exact colours of the official Fluir brand plate (the application icon).
  /// Only reproduced where that plate is the artwork itself — the splash and
  /// the native launch background. They are not general UI colours.
  static const logoPlate = Color(0xFF0070E0);
  static const logoWordmark = Color(0xFF4DFFA7);

  static const navy = Color(0xFF111827);
  static const background = Color(0xFFF6F7F9);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF687280);
  static const outline = Color(0xFFD8DEE7);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEA4444);
  static const success = Color(0xFF22C55E);
}

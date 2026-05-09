import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0D3B66); // Deep blue
  static const Color secondary = Color(0xFFD4A017); // Gold
  static const Color background = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF5F8FF);
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC62828);

  // Text colors for improved readability and contrast
  static const Color textPrimary = Color(
    0xFF1F2D3D,
  ); // Dark navy - for headings
  static const Color textSecondary = Color(
    0xFF566573,
  ); // Medium-dark gray - for body text
  static const Color textDisabled = Color(
    0xFF85929E,
  ); // Light gray - for disabled/hint text
}

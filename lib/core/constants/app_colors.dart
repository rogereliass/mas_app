import 'package:flutter/material.dart';

/// Centralized color definitions for the app
/// All colors used throughout the app are defined here
class AppColors {
  // Primary colors
  static const Color primaryBlue = Color(0xFF4169E1);
  static const Color accentBlue = Color(0xFF5B9AFF);
  
  // Background colors - Light theme
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color cardLight = Color(0xFFFFFFFF);
  
  // Background colors - Dark theme
  static const Color backgroundDark = Color(0xFF1A1F2E);
  static const Color surfaceDark = Color(0xFF252B3D);
  static const Color cardDark = Color(0xFF2D3548);
  
  // Text colors - Light theme
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF6B6B6B);
  static const Color textTertiaryLight = Color(0xFF9E9E9E);
  
  // Text colors - Dark theme
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textTertiaryDark = Color(0xFF808080);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);
  
  // Special colors
  static const Color publicAccessBadge = Color(0xFFFDB827);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF3A3A3A);
  
  // Button colors
  static const Color buttonPrimary = primaryBlue;
  static const Color buttonSecondaryLight = Color(0xFFFFFFFF);
  static const Color buttonSecondaryDark = Color(0xFF2D3548);
  
  // Overlay colors
  static const Color overlay = Color(0x66000000);
  static const Color shimmer = Color(0x33FFFFFF);
}

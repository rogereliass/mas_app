import 'package:flutter/material.dart';

/// Centralized color definitions for the app
/// All colors used throughout the app are defined here
class AppColors {
  // Scout Elite Design System Colors (Core Palette)
  static const Color scoutEliteNavy = Color(0xFF0F172A); // Richer navy (Slate 900) - Background
  static const Color cardDarkElevated = Color(0xFF1E293B); // Slightly lighter navy (Slate 800) - Cards/Surfaces
  static const Color goldAccent = Color(0xFFD4A74F); // Muted, elegant gold - Primary/Accent
  static const Color sectionHeaderGray = Color(0xFF94A3B8); // Slate 400 - Secondary Text
  
  // Leaderboard Header Themes (Royal/Gold Complement)
  static const Color leaderboardHeaderStart = Color(0xFF1E3A8A); // Royal Navy Blue
  static const Color leaderboardHeaderEnd = Color(0xFF0F172A); // Very dark navy / scoutEliteNavy

  // Primary colors (Mapped to Design System)
  static const Color primaryBlue =Color.fromARGB(255, 39, 92, 249); 
  static const Color accentBlue = Color.fromARGB(255, 69, 141, 255); 
  
  // Background colors - Light theme
  static const Color backgroundLight = Color(0xFFFAF7F2); // Light cream
  static const Color surfaceLight = Color(0xFFF5F2ED); // Slightly darker cream
  static const Color cardLight = Color(0xFFFFFFFF); // Keep cards white for contrast
  
  // Background colors - Dark theme
  static const Color backgroundDark = scoutEliteNavy;
  static const Color surfaceDark = cardDarkElevated;
  static const Color cardDark = cardDarkElevated;
  
  // Text colors - Light theme
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF6B6B6B);
  static const Color textTertiaryLight = Color(0xFF9E9E9E);
  
  // Text colors - Dark theme
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0B0); // Light gray for readability
  static const Color textTertiaryDark = sectionHeaderGray;
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);
  
  // Special colors
  static const Color publicAccessBadge = goldAccent; // Unified with gold
  static const Color divider = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF334155); // Slate 700
  
  // Button colors
  static const Color buttonPrimary = primaryBlue;
  static const Color buttonSecondaryLight = Color(0xFFFFFFFF);
  static const Color buttonSecondaryDark = cardDarkElevated;
  
  // Overlay colors
  static const Color overlay = Color(0x66000000);
  static const Color shimmer = Color(0x33FFFFFF);
  
  // Folder colors
  static const Color folderIconColor = goldAccent;
  static const Color folderBackgroundLight = Color(0xFFE8E4D0);
  static const Color folderBackgroundDark = Color(0xFF334155); // Slate 700 (Lighter than card)
  
  // Ranking & Medal Colors
  static const Color rankGold = Color(0xFFD4AF37); // Rich metallic Gold
  static const Color rankSilver = Color(0xFF94A3B8); // Slate 400 / Silver
  static const Color rankBronze = Color(0xFFB87333); // Classic deeper Bronze
  
  // File type colors
  static const Color fileTypePdf = Color(0xFFE53E3E);
  static const Color fileTypeImage = Color(0xFF48BB78);
  static const Color fileTypeVideo = Color(0xFF9F7AEA);
  static const Color fileTypeDocument = Color(0xFF4299E1);
  static const Color fileTypeMap = Color(0xFF9F7AEA);
  
  // Icon Badge Colors for Folder Types
  static const Color badgeYellow = goldAccent; // Unified
  static const Color badgePurple = Color(0xFF9F7AEA); 
  static const Color badgeBlue = Color(0xFF4299E1); 
  static const Color badgeOrange = Color(0xFFFF8A3D); 
  static const Color badgeTeal = Color(0xFF38B2AC); 
  static const Color badgeGreen = Color(0xFF48BB78); 
}

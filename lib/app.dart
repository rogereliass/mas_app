import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/config/theme_config.dart';
import 'core/config/theme_provider.dart';
import 'routing/app_router.dart';

/// Main application widget
/// 
/// This is the root widget of the app that:
/// - Consumes the ThemeProvider for theme management
/// - Configures Material 3 design system
/// - Sets up navigation routing
/// - Provides app-wide configuration
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes from ThemeProvider
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          // App identity
          title: 'Scout Digital Library',
          debugShowCheckedModeBanner: false,
          
          // Theme configuration - uses centralized theme system
          // Light theme for Brightness.light mode
          theme: AppTheme.lightTheme,
          // Dark theme for Brightness.dark mode
          darkTheme: AppTheme.darkTheme,
          // Current theme mode from provider (light/dark/system)
          themeMode: themeProvider.themeMode,
          
          // Navigation configuration
          // Initial route when app launches
          initialRoute: AppRouter.startup,
          // All app routes defined in centralized router
          routes: AppRouter.routes,
          // Handle unknown routes gracefully
          onUnknownRoute: AppRouter.onUnknownRoute,
        );
      },
    );
  }
}

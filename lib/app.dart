import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/config/theme_config.dart';
import 'core/config/theme_provider.dart';
import 'routing/app_router.dart';

/// Main application widget
/// 
/// Root widget that:
/// - Consumes ThemeProvider for theme management
/// - Configures Material 3 with centralized theme system
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
          
          // Theme configuration - uses centralized AppTheme
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          
          // Navigation configuration
          initialRoute: AppRouter.startup,
          routes: AppRouter.routes,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onUnknownRoute: AppRouter.onUnknownRoute,
        );
      },
    );
  }
}

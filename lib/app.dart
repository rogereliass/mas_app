import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/config/theme_config.dart';
import 'core/config/theme_provider.dart';
import 'core/constants/app_colors.dart';
import 'core/services/connectivity_service.dart';
import 'routing/app_router.dart';
import 'routing/navigation_service.dart';

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
          navigatorKey: NavigationService.navigatorKey,

          // Theme configuration - uses centralized AppTheme
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,

          // Navigation configuration
          initialRoute: AppRouter.startup,
          routes: AppRouter.routes,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onUnknownRoute: AppRouter.onUnknownRoute,
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();

            final isOffline = !ConnectivityService.instance.isOnline;
            final mediaQuery = MediaQuery.of(context);

            // When offline, add padding at top to account for banner so AppBar isn't covered
            final newMediaQuery = isOffline
                ? mediaQuery.copyWith(
                    padding: mediaQuery.padding.copyWith(
                      top: mediaQuery.padding.top + 40,
                    ),
                  )
                : mediaQuery;

            return MediaQuery(
              data: newMediaQuery,
              child: Stack(
                children: [
                  child,
                  if (isOffline)
                    Positioned(
                      top: mediaQuery.padding.top, // Position below status bar
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 40,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.warning.withValues(alpha: 0.3)
                              : AppColors.warning,
                          child: Text(
                            'Offline mode',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../startup/startup_page.dart';
import '../auth/ui/login_page.dart';
import '../library/ui/folder_page.dart';
import '../library/ui/folder_detail_page.dart';
import '../library/ui/all_folders_page.dart';
import '../library/ui/about_page.dart';

/// Centralized routing configuration for the application
/// 
/// This class manages all navigation routes in the app.
/// Benefits:
/// - Single source of truth for route names
/// - Easy to maintain and extend
/// - Prevents typos in route strings
/// - Enables type-safe navigation
class AppRouter {
  // Private constructor to prevent instantiation
  AppRouter._();

  // ============================================================================
  // ROUTE NAME CONSTANTS
  // ============================================================================
  
  /// Startup/landing page route
  static const String startup = '/';
  
  /// Login page route
  static const String login = '/login';
  
  /// Main library page route (root folder view)
  static const String library = '/library';
  
  /// All folders page route
  static const String allFolders = '/all-folders';
  
  /// About page route
  static const String about = '/about';

  // ============================================================================
  // ROUTE DEFINITIONS
  // ============================================================================
  
  /// Map of all routes in the application
  /// Add new routes here as the app grows
  static Map<String, WidgetBuilder> get routes => {
    startup: (context) => const StartupPage(),
    login: (context) => const LoginPage(),
    library: (context) => const LibraryHomePage(),
    allFolders: (context) => const AllFoldersPage(),
    about: (context) => const AboutPage(),
  };

  // ============================================================================
  // ROUTE HANDLERS
  // ============================================================================
  
  /// Handle unknown/undefined routes
  /// Returns a fallback page when user navigates to non-existent route
  static Route<dynamic>? onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Page Not Found'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Route: ${settings.name}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  startup,
                  (route) => false,
                ),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // NAVIGATION HELPERS
  // ============================================================================
  
  /// Navigate to startup page and clear navigation stack
  static void goToStartup(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      startup,
      (route) => false,
    );
  }

  /// Navigate to login page
  static Future<void> goToLogin(BuildContext context) {
    return Navigator.of(context).pushNamed(login);
  }

  /// Navigate to library page
  static Future<void> goToLibrary(BuildContext context) {
    return Navigator.of(context).pushNamed(library);
  }

  /// Navigate to all folders page
  static Future<void> goToAllFolders(BuildContext context) {
    return Navigator.of(context).pushNamed(allFolders);
  }

  /// Navigate to about page
  static Future<void> goToAbout(BuildContext context) {
    return Navigator.of(context).pushNamed(about);
  }

  /// Navigate to specific folder with dynamic route
  static Future<void> goToFolder(
    BuildContext context, {
    required String folderId,
    required String folderName,
    List<String>? breadcrumbs,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FolderDetailPage(
          folderId: folderId,
          folderName: folderName,
          breadcrumbs: breadcrumbs,
        ),
      ),
    );
  }
}



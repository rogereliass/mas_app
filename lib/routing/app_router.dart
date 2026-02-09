import 'package:flutter/material.dart';
import '../startup/startup_page.dart';
import '../auth/ui/login_page.dart';
import '../auth/ui/register_page.dart';
import '../auth/ui/register_success_page.dart';
import '../auth/ui/otp_verification_page.dart';
import '../home/home_page.dart';
import '../library/ui/folder_page.dart';
import '../library/ui/folder_detail_page.dart';
import '../library/ui/file_viewer_page.dart';
import '../library/ui/all_folders_page.dart';
import '../library/ui/about_page.dart';
import '../profile/profile_page.dart';
import '../home/pages/admin_approval/ui/user_acceptance_page.dart';

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
  
  /// Registration page route
  static const String register = '/register';
  
  /// Registration success page route
  static const String registerSuccess = '/register-success';
  
  /// OTP verification page route
  static const String otpVerification = '/otp-verification';
  
  /// Home page route (after login)
  static const String home = '/home';
  
  /// Main library page route (root folder view)
  static const String library = '/library';
  
  /// All folders page route
  static const String allFolders = '/all-folders';
  
  /// About page route
  static const String about = '/about';
  
  /// Profile page route
  static const String profile = '/profile';
  
  /// User acceptance page route (admin only)
  static const String userAcceptance = '/user-acceptance';

  // ============================================================================
  // ROUTE DEFINITIONS
  // ============================================================================
  
  /// Map of all routes in the application
  /// Add new routes here as the app grows
  static Map<String, WidgetBuilder> get routes => {
    startup: (context) => const StartupPage(),
    login: (context) => const LoginPage(),
    register: (context) => const RegisterPage(),
    registerSuccess: (context) => const RegisterSuccessPage(),
    home: (context) => const HomePage(),
    library: (context) => const LibraryHomePage(),
    allFolders: (context) => const AllFoldersPage(),
    about: (context) => const AboutPage(),
    profile: (context) => const ProfilePage(),
    userAcceptance: (context) => const UserAcceptancePage(),
  };

  // ============================================================================
  // ROUTE HANDLERS
  // ============================================================================
  
  /// Handle dynamic routes with arguments
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    // Handle OTP verification with arguments
    if (settings.name == otpVerification) {
      final args = settings.arguments as Map<String, dynamic>?;
      if (args != null && args['phoneNumber'] != null) {
        return MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            phoneNumber: args['phoneNumber'] as String,            password: args['password'] as String?,            isSignUp: args['isSignUp'] as bool? ?? false,
            metadata: args['metadata'] as Map<String, dynamic>?,
          ),
        );
      }
    }
    
    return null; // Let onUnknownRoute handle it
  }
  
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

  /// Navigate to file viewer with dynamic route
  static Future<void> goToFileViewer(
    BuildContext context, {
    required String fileId,
    required String fileName,
    required String fileType,
    int? fileSizeBytes,
    String? fileUrl,
    String? description,
    String? publisher,
    String? language,
    int? pageCount,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FileViewerPage(
          fileId: fileId,
          fileName: fileName,
          fileType: fileType,
          fileSizeBytes: fileSizeBytes,
          fileUrl: fileUrl,
          description: description,
          publisher: publisher,
          language: language,
          pageCount: pageCount,
        ),
      ),
    );
  }
}



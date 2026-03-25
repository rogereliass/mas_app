import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/logic/auth_provider.dart';
import '../core/services/connectivity_service.dart';
import '../startup/startup_page.dart';
import '../auth/ui/login_page.dart';
import '../auth/ui/register_page.dart';
import '../auth/ui/register_success_page.dart';
import '../auth/ui/otp_verification_page.dart';
import '../auth/ui/forgot_password_page.dart';
import '../auth/ui/reset_password_page.dart';
import '../home/home_page.dart';
import '../library/ui/folder_page.dart';
import '../library/ui/folder_detail_page.dart';
import '../library/ui/file_viewer_page.dart';
import '../library/ui/all_folders_page.dart';
import '../library/ui/about_page.dart';
import '../profile/profile_page.dart';
import '../home/pages/user_approval/ui/user_acceptance_page.dart';
import '../home/pages/user_management/ui/user_management_page.dart';
import '../home/pages/season_management/ui/season_management_page.dart';
import '../home/pages/patrols_management/ui/patrols_management_page.dart';
import '../home/pages/eftekad/ui/eftekad_page.dart';
import '../home/pages/role_management/ui/role_management_page.dart';
import '../meetings/meetings_page.dart';

class MeetingsTab {
  MeetingsTab._();

  static const int management = 0;
  static const int attendance = 1;
  static const int points = 2;
}

class MeetingsRouteArgs {
  const MeetingsRouteArgs({
    this.initialTabIndex = MeetingsTab.management,
    this.meetingId,
  });

  final int initialTabIndex;
  final String? meetingId;
}

enum ProtectedRouteState {
  allow,
  denyUnauthenticated,
  pendingProfile,
  denyProfileUnavailable,
  denyInsufficientRole,
}

class ProtectedRouteEvaluation {
  const ProtectedRouteEvaluation(this.state);

  final ProtectedRouteState state;

  bool get isAllowed => state == ProtectedRouteState.allow;
}

ProtectedRouteEvaluation evaluateProtectedRouteState({
  required bool isAuthenticated,
  required bool isOnline,
  required bool profileLoading,
  required bool hasProfile,
  required int currentUserRoleRank,
  required int? minRoleRank,
  required Duration unresolvedProfileDuration,
  required Duration unresolvedProfileTimeout,
}) {
  if (!isAuthenticated) {
    return const ProtectedRouteEvaluation(ProtectedRouteState.denyUnauthenticated);
  }

  if (profileLoading && !hasProfile) {
    return const ProtectedRouteEvaluation(ProtectedRouteState.pendingProfile);
  }

  if (!hasProfile) {
    if (!isOnline) {
      return const ProtectedRouteEvaluation(ProtectedRouteState.denyProfileUnavailable);
    }

    if (unresolvedProfileDuration >= unresolvedProfileTimeout) {
      return const ProtectedRouteEvaluation(ProtectedRouteState.denyProfileUnavailable);
    }
    return const ProtectedRouteEvaluation(ProtectedRouteState.pendingProfile);
  }

  if (minRoleRank != null && currentUserRoleRank < minRoleRank) {
    return const ProtectedRouteEvaluation(ProtectedRouteState.denyInsufficientRole);
  }

  return const ProtectedRouteEvaluation(ProtectedRouteState.allow);
}

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
  
  /// Forgot password page route
  static const String forgotPassword = '/forgot-password';
  
  /// Reset password page route
  static const String resetPassword = '/reset-password';
  
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

  /// User management page route (admin and troop roles)
  static const String userManagement = '/user-management';
  
  /// Season management page route (admin only)
  static const String seasonManagement = '/season-management';

  /// Patrols management page route (admin and troop roles)
  static const String patrolsManagement = '/patrols-management';

  /// Meetings page route
  static const String meetings = '/meetings';

  /// Eftekad page route (troop management)
  static const String eftekad = '/eftekad';

  /// Roles management page route (admin only)
  static const String manageRoles = '/manage-roles';

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
    forgotPassword: (context) => const ForgotPasswordPage(),
    home: (context) => const HomePage(),
    library: (context) => const LibraryHomePage(),
    allFolders: (context) => const AllFoldersPage(),
    about: (context) => const AboutPage(),
    profile: (context) => const ProfilePage(),
    // Dynamic routes handled in onGenerateRoute: otpVerification, resetPassword, userAcceptance
  };

  // ============================================================================
  // ROUTE HANDLERS
  // ============================================================================
  
  /// Handle dynamic routes with arguments
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    // Handle OTP verification with arguments
    if (settings.name == otpVerification) {
      final args = settings.arguments as Map<String, dynamic>?;
      final email = args?['email'] as String? ?? args?['phoneNumber'] as String?;
      if (args != null && email != null) {
        return MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            email: email,
            password: args['password'] as String?,
            isSignUp: args['isSignUp'] as bool? ?? false,
            isPasswordReset: args['isPasswordReset'] as bool? ?? false,
            metadata: args['metadata'] as Map<String, dynamic>?,
          ),
        );
      }
    }
    
    // Handle Reset Password with arguments
    if (settings.name == resetPassword) {
      final args = settings.arguments as Map<String, dynamic>?;
      final email = args?['email'] as String? ?? args?['phoneNumber'] as String?;
      if (args != null && email != null) {
        return MaterialPageRoute(
          builder: (context) => ResetPasswordPage(
            email: email,
          ),
        );
      }
    }
    
    // Handle User Acceptance with role context
    if (settings.name == userAcceptance) {
      return _buildProtectedRoute(
        settings: settings,
        minRoleRank: 60,
        routeLabel: 'User Acceptance',
        child: const UserAcceptancePage(),
      );
    }

    // Handle User Management with role context
    if (settings.name == userManagement) {
      return _buildProtectedRoute(
        settings: settings,
        minRoleRank: 60,
        routeLabel: 'User Management',
        child: const UserManagementPage(),
      );
    }
    
    // Handle Season Management
    if (settings.name == seasonManagement) {
      return _buildProtectedRoute(
        settings: settings,
        minRoleRank: 90,
        routeLabel: 'Season Management',
        child: const SeasonManagementPage(),
      );
    }

    // Handle Patrols Management with role context
    if (settings.name == patrolsManagement) {
      return _buildProtectedRoute(
        settings: settings,
        minRoleRank: 60,
        routeLabel: 'Patrols Management',
        child: const PatrolsManagementPage(),
      );
    }
    
    // Handle Meetings with role context
    if (settings.name == meetings) {
      final args = settings.arguments;
      if (args is MeetingsRouteArgs) {
        return _buildProtectedRoute(
          settings: settings,
          routeLabel: 'Meetings',
          child: MeetingsPage(
            initialTabIndex: args.initialTabIndex,
            initialMeetingId: args.meetingId,
          ),
        );
      }

      return _buildProtectedRoute(
        settings: settings,
        routeLabel: 'Meetings',
        child: const MeetingsPage(),
      );
    }

    // Handle Eftekad placeholder page
    if (settings.name == eftekad) {
      return _buildProtectedRoute(
        settings: settings,
        minRoleRank: 60,
        routeLabel: 'Eftekad',
        child: const EftekadPage(),
      );
    }

    // Handle Manage Roles placeholder page
    if (settings.name == manageRoles) {
      return _buildProtectedRoute(
        settings: settings,
        minRoleRank: 100,
        routeLabel: 'Role Management',
        child: const RoleManagementPage(),
      );
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

  static MaterialPageRoute _buildProtectedRoute({
    required RouteSettings settings,
    required String routeLabel,
    required Widget child,
    int? minRoleRank,
  }) {
    return MaterialPageRoute(
      settings: settings,
      builder: (context) => _ProtectedRoutePage(
        routeLabel: routeLabel,
        minRoleRank: minRoleRank,
        child: child,
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

class _ProtectedRoutePage extends StatefulWidget {
  const _ProtectedRoutePage({
    required this.routeLabel,
    required this.child,
    this.minRoleRank,
  });

  final String routeLabel;
  final Widget child;
  final int? minRoleRank;

  @override
  State<_ProtectedRoutePage> createState() => _ProtectedRoutePageState();
}

class _ProtectedRoutePageState extends State<_ProtectedRoutePage> {
  bool _requestedProfileRefresh = false;
  DateTime? _profileCheckStartedAt;
  StreamSubscription<bool>? _connectivitySubscription;
  static const Duration _profileCheckTimeout = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = ConnectivityService.instance.statusStream.listen((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    final unresolvedDuration = _profileCheckStartedAt == null
        ? Duration.zero
        : DateTime.now().difference(_profileCheckStartedAt!);
    final guardEvaluation = evaluateProtectedRouteState(
      isAuthenticated: authProvider.isAuthenticated,
      isOnline: ConnectivityService.instance.isOnline,
      profileLoading: authProvider.profileLoading,
      hasProfile: authProvider.currentUserProfile != null,
      currentUserRoleRank: authProvider.currentUserRoleRank,
      minRoleRank: widget.minRoleRank,
      unresolvedProfileDuration: unresolvedDuration,
      unresolvedProfileTimeout: _profileCheckTimeout,
    );

    if (guardEvaluation.state == ProtectedRouteState.denyUnauthenticated) {
      return _buildAccessDenied(
        context,
        message: 'Please sign in to continue.',
        redirectToLogin: true,
      );
    }

    if (guardEvaluation.state == ProtectedRouteState.pendingProfile &&
        authProvider.profileLoading) {
      _profileCheckStartedAt = null;
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (guardEvaluation.state == ProtectedRouteState.pendingProfile &&
        authProvider.currentUserProfile == null) {
      _profileCheckStartedAt ??= DateTime.now();

      if (!_requestedProfileRefresh) {
        _requestedProfileRefresh = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<AuthProvider>().refreshProfile();
        });
      }

      return _buildAccessPending(
        context,
        message: 'Checking access permissions. Please wait...',
      );
    }

    if (guardEvaluation.state == ProtectedRouteState.denyProfileUnavailable) {
      final offline = !ConnectivityService.instance.isOnline;
      return _buildAccessDenied(
        context,
        message: offline
            ? 'Offline mode: this section needs a previously cached profile. Connect once, then retry offline.'
            : 'Unable to confirm your access right now. Please retry.',
        onRetry: _retryAccessCheck,
        retryLabel: 'Retry',
      );
    }

    _profileCheckStartedAt = null;

    if (guardEvaluation.state == ProtectedRouteState.denyInsufficientRole) {
      return _buildAccessDenied(
        context,
        message: 'You do not have access to ${widget.routeLabel}.',
      );
    }

    return widget.child;
  }

  Widget _buildAccessPending(BuildContext context, {required String message}) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checking Access')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessDenied(
    BuildContext context, {
    required String message,
    bool redirectToLogin = false,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Access Restricted')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 56,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final destination = redirectToLogin ? AppRouter.login : AppRouter.home;
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    destination,
                    (route) => false,
                  );
                },
                child: Text(redirectToLogin ? 'Go to Login' : 'Go to Home'),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: onRetry,
                  child: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _retryAccessCheck() {
    setState(() {
      _requestedProfileRefresh = false;
      _profileCheckStartedAt = null;
    });
    context.read<AuthProvider>().refreshProfile();
  }
}



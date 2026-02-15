import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config/theme_provider.dart';
import '../core/constants/app_colors.dart';
import '../routing/app_router.dart';
import '../auth/logic/auth_provider.dart';

/// Startup/Landing page with public access to library
/// 
/// This is the first screen users see when launching the app.
/// Features:
/// - Auto-redirect to home if user is already logged in
/// - App logo with theme toggle
/// - Hero image showcasing the library
/// - Public access badge
/// - Call-to-action buttons for Library and Login
/// - Informative messaging about public access
/// 
/// Design follows the specification exactly with proper theming support
class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  @override
  void initState() {
    super.initState();
    // Check auth state and redirect immediately if logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      debugPrint('🚀 StartupPage - Checking auth state...');
      debugPrint('   isAuthenticated: ${authProvider.isAuthenticated}');
      
      if (authProvider.isAuthenticated) {
        debugPrint('✅ User logged in, redirecting to home immediately...');
        // Redirect immediately, HomePage will handle loading roles
        Navigator.of(context).pushReplacementNamed(AppRouter.home);
      } else {
        debugPrint('ℹ️ No active session, staying on startup page');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Header with logo and theme toggle
              _HeaderSection(),
              
              const SizedBox(height: 40),
              
              // Main scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Hero image with public access badge
                      _HeroImageSection(),
                      
                      const SizedBox(height: 48),
                      
                      // Title: "Scout Digital Library"
                      _TitleSection(),
                      
                      const SizedBox(height: 16),
                      
                      // Subtitle description
                      _SubtitleSection(),
                      
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
              
              // Action buttons (Library & Login)
              _ActionButtonsSection(),
              
              const SizedBox(height: 16),
              
              // Footer text
              _FooterSection(),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER SECTION - Logo and Theme Toggle
// ============================================================================

/// Header section with app logo and theme toggle button
class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // App logo container
        _LogoWidget(),
        
        // Theme toggle button
        _ThemeToggleButton(),
      ],
    );
  }
}

/// App logo widget with fallback icon
class _LogoWidget extends StatelessWidget {
  // Logo dimensions
  static const double _logoSize = 64.0;
  static const double _borderRadius = 12.0;
  // Asset path for logo image
  static const String _logoAssetPath = 'assets/images/mas_logo.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: _logoSize,
      height: _logoSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_borderRadius),
        child: Image.asset(
          _logoAssetPath,
          fit: BoxFit.cover,
          // Fallback if image fails to load
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.image,
                color: theme.colorScheme.onPrimary,
                size: 32,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Theme toggle button that switches between light and dark modes
class _ThemeToggleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Determine if current theme is dark
        final isDark = themeProvider.isDarkMode || 
                      Theme.of(context).brightness == Brightness.dark;
        
        return IconButton(
          onPressed: () => themeProvider.toggleTheme(),
          icon: Icon(
            // Show sun icon in dark mode, moon icon in light mode
            isDark ? Icons.light_mode : Icons.dark_mode,
          ),
          iconSize: 28,
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        );
      },
    );
  }
}

// ============================================================================
// HERO IMAGE SECTION - Main visual with public access badge
// ============================================================================

/// Hero image section with public access indicator badge
class _HeroImageSection extends StatelessWidget {
  // Image configuration constants
  static const double _imageHeight = 330.0;
  static const double _imageBorderRadius = 24.0;
  static const double _shadowBlurRadius = 20.0;
  static const Offset _shadowOffset = Offset(0, 10);
  // Asset path for hero image
  static const String _heroImageAssetPath = 'assets/images/camp_30Y.jpg';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Stack(
      children: [
        // Main hero image with shadow
        Container(
          width: double.infinity,
          height: _imageHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_imageBorderRadius),
            boxShadow: [
              BoxShadow(
                // Use theme-aware shadow color
                color: theme.brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.2),
                blurRadius: _shadowBlurRadius,
                offset: _shadowOffset,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_imageBorderRadius),
            child: Image.asset(
              _heroImageAssetPath,
              fit: BoxFit.cover,
              // Fallback if image fails to load
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: theme.colorScheme.surface,
                  child: Center(
                    child: Icon(
                      Icons.image,
                      size: 64,
                      color: theme.iconTheme.color?.withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        // Public access badge overlay
        const Positioned(
          top: 16,
          left: 16,
          child: _PublicAccessBadge(),
        ),
      ],
    );
  }
}

/// Public access badge indicating content is freely available
class _PublicAccessBadge extends StatelessWidget {
  const _PublicAccessBadge();

  // Badge styling constants
  static const double _badgeBorderRadius = 20.0;
  static const double _indicatorSize = 8.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // Semi-transparent background for overlay effect
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(_badgeBorderRadius),
        border: Border.all(
          color: AppColors.publicAccessBadge.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicator dot
          Container(
            width: _indicatorSize,
            height: _indicatorSize,
            decoration: const BoxDecoration(
              color: AppColors.publicAccessBadge,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Badge text
          const Text(
            'PUBLIC ACCESS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TITLE SECTION - App name with styled text
// ============================================================================

/// Title section displaying "Scout Digital Library" with proper styling
class _TitleSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final theme = Theme.of(context);
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          // "Scout" in theme text color
          TextSpan(
            text: 'MAS ',
            style: textTheme.displayMedium?.copyWith(
              // Use theme-aware text color
              color: theme.colorScheme.onSurface,
            ),
          ),
          // "Digital Library" in brand blue
          TextSpan(
            text: 'Digital Library',
            style: textTheme.displayMedium?.copyWith(
              // Use primary color from theme
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SUBTITLE SECTION - Description text
// ============================================================================

/// Subtitle section with app description
class _SubtitleSection extends StatelessWidget {
  // Content text - can be easily changed or localized
  static const String _subtitleText = 
      'Your premier platform for knowledge and continuous learning. '
      'Explore thousands of resources without even signing up.';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        _subtitleText,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.5, // Line height for better readability
        ),
      ),
    );
  }
}

// ============================================================================
// ACTION BUTTONS SECTION - Primary CTAs
// ============================================================================

/// Action buttons section with Library and Login buttons
class _ActionButtonsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Primary button - Library (Browse without login)
        _LibraryButton(),
        
        const SizedBox(height: 16),
        
        // Secondary button - Login (For registered users)
        _LoginButton(),
      ],
    );
  }
}

/// Primary Library button - navigate to public library
class _LibraryButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // Use centralized router for navigation
          AppRouter.goToLibrary(context);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.auto_stories, size: 24),
            SizedBox(width: 12),
            Text('Library'),
          ],
        ),
      ),
    );
  }
}

/// Secondary Login button - navigate to authentication
class _LoginButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          // Use centralized router for navigation
          AppRouter.goToLogin(context);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.login, size: 24),
            SizedBox(width: 12),
            Text('Login'),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FOOTER SECTION - Informational text
// ============================================================================

/// Footer section with informational message
class _FooterSection extends StatelessWidget {
  // Content text - can be easily changed or localized
  static const String _footerText = 
      'Start browsing immediately • No account needed';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Text(
      _footerText,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        // Slightly transparent for subtle appearance
        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.9),
      ),
    );
  }
}


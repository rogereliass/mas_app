import 'package:flutter/material.dart';
import '../../../routing/app_router.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import 'components/auth_buttons.dart';

/// Registration Success Page
/// 
/// Theme-aware confirmation screen after successful registration
/// Uses reusable bottom nav component
class RegisterSuccessPage extends StatelessWidget {
  const RegisterSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/mas_logo.png',
          height: 48,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withValues(alpha: 0.95),
              theme.colorScheme.tertiary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
  
                    // Success icon with glow effect
                    _buildSuccessIcon(context),
  
                    const SizedBox(height: 48),
  
                    // Title
                    Text(
                      'Submitted!',
                      style: theme.textTheme.displayLarge?.copyWith(
                        color: theme.brightness == Brightness.light 
                            ? const Color(0xFF001F3F) // Navy blue anchor
                            : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
  
                    const SizedBox(height: 16),
  
                    // Message
                    Text(
                      'Thank you for your contribution. Your\nsubmission has been sent to a Unit\nLeader for approval.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                    ),
  
                    const Spacer(),
  
                    // Action button
                    PrimaryButton(
                      text: 'Go to Public Library',
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRouter.library,
                          (route) => false,
                        );
                      },
                    ),
  
                    const SizedBox(height: 100), // Raised button upwards
                  ],
                ),
              ),
            ),
            // Floating Navbar at Bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: const AppBottomNavBar(
                currentPage: 'library',
                isAuthenticated: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.tertiary.withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.tertiary.withValues(alpha: 0.5),
            width: 2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.tertiary.withValues(alpha: 0.15),
              colorScheme.tertiary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Icon(
          Icons.check_circle_rounded,
          size: 70,
          color: colorScheme.tertiary,
        ),
      ),
    );
  }
}


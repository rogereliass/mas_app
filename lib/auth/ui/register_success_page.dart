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
        title: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.tertiary,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.group,
                color: colorScheme.tertiary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'SCOUT LOGO',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
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
                    style: theme.textTheme.displayLarge,
                  ),

                  const SizedBox(height: 16),

                  // Message
                  Text(
                    'Thank you for your contribution. Your\nsubmission has been sent to a Unit\nLeader for approval.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                      height: 1.5,
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

                  const SizedBox(height: 32),
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
    );
  }

  Widget _buildSuccessIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.tertiary.withOpacity(0.4),
            blurRadius: 60,
            spreadRadius: 20,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.tertiary,
            width: 4,
          ),
          gradient: RadialGradient(
            colors: [
              colorScheme.tertiary.withOpacity(0.2),
              colorScheme.surface.withOpacity(0),
            ],
          ),
        ),
        child: Icon(
          Icons.check,
          size: 80,
          color: colorScheme.tertiary,
        ),
      ),
    );
  }
}

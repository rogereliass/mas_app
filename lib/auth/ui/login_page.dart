import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routing/app_router.dart';
import 'components/custom_text_field.dart';
import 'components/auth_buttons.dart';

/// Login Page
/// 
/// Allows users to sign in with email/password or social providers
/// Includes navigation to registration and password recovery
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement Supabase email/password login
      // final response = await Supabase.instance.client.auth.signInWithPassword(
      //   email: _emailController.text.trim(),
      //   password: _passwordController.text,
      // );
      // 
      // if (response.user != null) {
      //   Navigator.pushReplacementNamed(context, AppRouter.library);
      // }

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Navigate to library
      Navigator.pushReplacementNamed(context, AppRouter.library);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSocialLogin(String provider) async {
    // TODO: Implement social authentication
    // For Google:
    // await Supabase.instance.client.auth.signInWithOAuth(
    //   Provider.google,
    //   redirectTo: 'your-app-scheme://login-callback',
    // );
    // 
    // For Apple:
    // await Supabase.instance.client.auth.signInWithOAuth(
    //   Provider.apple,
    //   redirectTo: 'your-app-scheme://login-callback',
    // );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider sign-in not yet implemented')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Logo and branding
                _buildHeader(),

                const SizedBox(height: 48),

                // Email field
                CustomTextField(
                  label: 'Email or Username',
                  placeholder: 'Enter your email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    // TODO: Add proper email validation
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Password field
                CustomTextField(
                  label: 'Password',
                  placeholder: 'Enter your password',
                  controller: _passwordController,
                  isObscured: !_isPasswordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Forgot password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: Navigate to forgot password page
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password recovery not yet implemented'),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.tertiary,
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login button
                PrimaryButton(
                  text: 'Log In',
                  icon: Icons.arrow_forward,
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 32),

                // Divider
                _buildDivider(),

                const SizedBox(height: 24),

                // Social login buttons
                Row(
                  children: [
                    SocialButton(
                      provider: 'Google',
                      icon: Icons.g_mobiledata,
                      onPressed: () => _handleSocialLogin('Google'),
                    ),
                    const SizedBox(width: 16),
                    SocialButton(
                      provider: 'Apple',
                      icon: Icons.apple,
                      onPressed: () => _handleSocialLogin('Apple'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Don\'t have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRouter.register);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.publicAccessBadge,
                      ),
                      child: const Text(
                        'Register Now',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        // App icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.menu_book,
            size: 56,
            color: colorScheme.onPrimary,
          ),
        ),

        const SizedBox(height: 16),

        // Badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.dividerTheme.color!,
              width: 1,
            ),
          ),
          child: Text(
            'SCOUT LIBRARY',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Title
        Text(
          'Welcome Back',
          style: theme.textTheme.displayLarge,
        ),

        const SizedBox(height: 12),

        // Subtitle
        Text(
          'Sign in to access your digital\nbookshelf and resources.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.textTheme.bodySmall?.color,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        const Expanded(
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR CONTINUE WITH',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ),
        const Expanded(
          child: Divider(),
        ),
      ],
    );
  }
}
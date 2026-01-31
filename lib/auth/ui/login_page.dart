import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routing/app_router.dart';
import 'components/custom_text_field.dart';
import 'components/auth_buttons.dart';
import 'components/auth_error_dialog.dart';

/// Login Page
///
/// Allows users to sign in with phone number and password
/// Includes field validation and error handling
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove spaces, dashes, parentheses for validation
    final cleanNumber = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check if it contains only digits and optional + at start
    if (!RegExp(r'^\+?\d+$').hasMatch(cleanNumber)) {
      return 'Please enter a valid phone number';
    }

    // Check minimum length (10 digits for US numbers)
    final digitsOnly = cleanNumber.replaceAll('+', '');
    if (digitsOnly.length < 10) {
      return 'Phone number must be at least 10 digits';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  Future<void> _handleLogin() async {
    // Clear any previous errors
    Provider.of<AuthProvider>(context, listen: false).clearError();

    // Validate phone number
    final phoneError = _validatePhoneNumber(_phoneController.text);
    if (phoneError != null) {
      await AuthErrorDialog.showError(
        context: context,
        message: phoneError,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Send OTP to phone number
      final success = await authProvider.sendSignInOtp(
        phoneNumber: _phoneController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        // Navigate to OTP verification page
        Navigator.pushNamed(
          context,
          AppRouter.otpVerification,
          arguments: {
            'phoneNumber': _phoneController.text.trim(),
            'isSignUp': false,
          },
        );
      } else {
        // Show error dialog
        await AuthErrorDialog.showError(
          context: context,
          message:
              authProvider.errorMessage ?? 'Failed to send OTP. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      await AuthErrorDialog.showError(
        context: context,
        message: 'An unexpected error occurred. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.startup,
            (route) => false,
          ),
        ),
      ),
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

                // Phone number field
                CustomTextField(
                  label: 'Phone Number',
                  placeholder: '+20 100 123 4567',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhoneNumber,
                ),

                const SizedBox(height: 32),

                // Info text
                Text(
                  'We will send you a verification code via SMS',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Login button
                PrimaryButton(
                  text: 'Send OTP',
                  icon: Icons.arrow_forward,
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
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
          child: Icon(Icons.menu_book, size: 56, color: colorScheme.onPrimary),
        ),

        const SizedBox(height: 16),

        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerTheme.color!, width: 1),
          ),
          child: Text(
            'SCOUT LIBRARY',
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
          ),
        ),

        const SizedBox(height: 32),

        // Title
        Text('Welcome Back', style: theme.textTheme.displayLarge),

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
}

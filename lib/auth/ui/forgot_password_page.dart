import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routing/app_router.dart';
import 'components/custom_text_field.dart';
import 'components/auth_buttons.dart';
import 'components/auth_error_dialog.dart';

/// Forgot Password Page - Step 1
///
/// Allows users to enter their phone number to receive password reset OTP
/// Security: Rate limiting implemented in OTP verification page (max 2 attempts)
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
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

    // Check minimum length (10 digits)
    final digitsOnly = cleanNumber.replaceAll('+', '');
    if (digitsOnly.length < 10) {
      return 'Phone number must be at least 10 digits';
    }

    return null;
  }

  Future<void> _handleSendOtp() async {
    // Clear any previous errors
    Provider.of<AuthProvider>(context, listen: false).clearError();

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Send password reset OTP
      final success = await authProvider.sendPasswordResetOtp(
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
            'isPasswordReset': true,
          },
        );
      } else {
        // Show error dialog
        await AuthErrorDialog.showError(
          context: context,
          message: authProvider.errorMessage ?? 'Failed to send verification code',
        );
      }
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(theme, colorScheme),

                const SizedBox(height: 48),

                // Phone number field
                CustomTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  placeholder: '+20 123 456 7890',
                  keyboardType: TextInputType.phone,
                  validator: _validatePhoneNumber,
                ),

                const SizedBox(height: 24),

                // Send OTP button
                PrimaryButton(
                  text: 'Send Verification Code',
                  icon: Icons.send,
                  onPressed: _handleSendOtp,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 32),

                // Security notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We\'ll send a verification code to your phone number. '
                          'You\'ll be able to set a new password after verification.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Back to login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Remember your password? ',
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.publicAccessBadge,
                      ),
                      child: const Text(
                        'Back to Login',
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

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        // Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_reset,
            size: 40,
            color: colorScheme.onPrimaryContainer,
          ),
        ),

        const SizedBox(height: 24),

        // Title
        Text(
          'Reset Password',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        // Subtitle
        Text(
          'Enter your phone number and we\'ll send\nyou a verification code to reset your password.',
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

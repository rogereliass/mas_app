import 'package:flutter/material.dart';
import 'package:masapp/core/constants/app_colors.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../auth/logic/auth_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../routing/app_router.dart';
import 'components/auth_error_dialog.dart';

/// OTP Verification Screen
///
/// Allows users to enter the OTP code sent to their email
/// Supports both signup and password reset flows
class OtpVerificationPage extends StatefulWidget {
  final String email;
  final String? password;
  final bool isSignUp;
  final bool isPasswordReset;
  final Map<String, dynamic>? metadata;

  const OtpVerificationPage({
    super.key,
    required this.email,
    this.password,
    this.isSignUp = false,
    this.isPasswordReset = false,
    this.metadata,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _resendCountdown = 60;
  Timer? _resendTimer;
  bool _canResend = false;
  int _attemptCount = 0;
  int _resendCount = 0;
  
  int get _maxAttempts => 3;
  int get _maxResends => 3;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _rollbackSignupAuthIfNeeded({
    required AuthProvider authProvider,
    required String reason,
  }) async {
    if (widget.isPasswordReset) {
      return;
    }

    if (authProvider.currentUser == null) {
      return;
    }

    debugPrint('⚠️ Signup rollback triggered: $reason');
    final rollbackSuccess = await authProvider.deleteCurrentUser();
    if (!rollbackSuccess) {
      debugPrint('⚠️ Signup rollback failed; auth user may still exist.');
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend || _isLoading) return;

    // Check if max resend limit reached
    if (_resendCount >= _maxResends) {
      final errorMessage = widget.isPasswordReset
          ? 'Maximum reset email resend limit reached. Please try again later or contact support.'
          : 'Maximum OTP resend limit reached. Please try registering again later.';

      if (!widget.isPasswordReset) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await _rollbackSignupAuthIfNeeded(
          authProvider: authProvider,
          reason: 'max OTP resends reached',
        );
      }
      
      await AuthErrorDialog.showError(
        context: context,
        message: errorMessage,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Clear OTP fields
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();

      // Reset attempt counter when getting new OTP
      setState(() {
        _attemptCount = 0;
      });

      // Resend verification based on flow type
      if (widget.isPasswordReset) {
        final success = await authProvider.sendPasswordResetOtp(
          email: widget.email,
        );

        if (!mounted) return;

        if (success) {
          // Increment resend counter
          setState(() {
            _resendCount++;
          });

          final remainingResends = _maxResends - _resendCount;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'OTP resent successfully${remainingResends > 0 
                    ? '. $remainingResends resend${remainingResends != 1 ? "s" : ""} remaining'
                    : '. This was your last resend'}',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          _startResendTimer();
        } else {
          final errorMessage =
              authProvider.errorMessage ?? 'Failed to resend OTP';
          await _rollbackSignupAuthIfNeeded(
            authProvider: authProvider,
            reason: 'resend OTP request failed',
          );
          if (errorMessage == AuthRepository.otpEmailSendFailureMessage) {
            await AuthErrorDialog.showEmailOtpFallback(context: context);
          } else {
            await AuthErrorDialog.showError(
              context: context,
              message: errorMessage,
            );
          }
        }
      } else if (widget.password != null) {
        // Signup flow
        final success = await authProvider.signUpWithEmailOtp(
          email: widget.email,
          password: widget.password!,
          metadata: widget.metadata,
        );

        if (!mounted) return;

        if (success) {
          // Increment resend counter
          setState(() {
            _resendCount++;
          });

          final remainingResends = _maxResends - _resendCount;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'OTP resent successfully${remainingResends > 0 
                    ? '. $remainingResends resend${remainingResends != 1 ? "s" : ""} remaining'
                    : '. This was your last resend'}',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          _startResendTimer();
        } else {
          final errorMessage =
              authProvider.errorMessage ?? 'Failed to resend OTP';
          if (errorMessage == AuthRepository.otpEmailSendFailureMessage) {
            await AuthErrorDialog.showEmailOtpFallback(context: context);
          } else {
            await AuthErrorDialog.showError(
              context: context,
              message: errorMessage,
            );
          }
        }
      } else {
        // Password not available - user needs to go back
        await _rollbackSignupAuthIfNeeded(
          authProvider: authProvider,
          reason: 'signup resend requested without password',
        );
        await AuthErrorDialog.showError(
          context: context,
          message: 'Please go back and submit registration form again',
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

  Future<void> _verifyOtp() async {
    final otpCode = _otpControllers.map((c) => c.text).join();

    if (otpCode.length != 6) {
      await AuthErrorDialog.showError(
        context: context,
        message: 'Please enter all 6 digits',
      );
      return;
    }

    // Check if max attempts reached
    if (_attemptCount >= _maxAttempts) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await _rollbackSignupAuthIfNeeded(
        authProvider: authProvider,
        reason: 'max OTP attempts reached',
      );

      await AuthErrorDialog.showError(
        context: context,
        message: 'Too many failed attempts. Please request a new OTP.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Password reset flow: verify OTP then proceed to password update.
      if (widget.isPasswordReset) {
        final otpSuccess = await authProvider.verifyPasswordResetOtp(
          email: widget.email,
          otpCode: otpCode,
        );

        if (!mounted) return;

        if (!otpSuccess) {
          setState(() {
            _attemptCount++;
            _isLoading = false;
          });

          for (var controller in _otpControllers) {
            controller.clear();
          }
          _focusNodes[0].requestFocus();

          final remainingAttempts = _maxAttempts - _attemptCount;
          await AuthErrorDialog.showError(
            context: context,
            message: authProvider.errorMessage ?? 'Invalid OTP code${remainingAttempts > 0 
                    ? '\n$remainingAttempts attempt${remainingAttempts != 1 ? "s" : ""} remaining'
                    : ''}',
          );
          return;
        }

        Navigator.of(context).pushReplacementNamed(
          AppRouter.resetPassword,
          arguments: {'email': widget.email},
        );
        return;
      }

      // Signup flow: verify OTP
      final otpSuccess = await authProvider.verifySignUpOtp(
        email: widget.email,
        otpCode: otpCode,
      );

      if (!mounted) return;

      if (!otpSuccess) {
        // Increment attempt counter
        setState(() {
          _attemptCount++;
          _isLoading = false;
        });

        // Clear OTP fields for retry
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();

        // Show error with attempt count
        final remainingAttempts = _maxAttempts - _attemptCount;
        await _rollbackSignupAuthIfNeeded(
          authProvider: authProvider,
          reason: 'OTP verification failed',
        );

        await AuthErrorDialog.showError(
          context: context,
          message: authProvider.errorMessage ?? 'Invalid OTP code${remainingAttempts > 0 
                  ? '\n$remainingAttempts attempt${remainingAttempts != 1 ? "s" : ""} remaining'
                  : ''}',
        );
        return;
      }

      debugPrint('=== OTP VERIFIED SUCCESSFULLY ===');
      debugPrint('Current user: ${authProvider.currentUser?.id}');
      debugPrint('Has metadata: ${widget.metadata != null}');
      debugPrint('Metadata fields: ${widget.metadata?.keys.toList()}');

      // Step 2: Set initial password for future email+password sign-ins.
      if (widget.password != null && widget.password!.isNotEmpty) {
        final passwordSet = await authProvider.setInitialPassword(
          password: widget.password!,
        );

        if (!mounted) return;

        if (!passwordSet) {
          await _rollbackSignupAuthIfNeeded(
            authProvider: authProvider,
            reason: 'setInitialPassword failed',
          );

          if (!mounted) return;

          await AuthErrorDialog.showError(
            context: context,
            message:
                authProvider.errorMessage ?? 'Failed to finalize account setup.',
          );
          return;
        }
      }

      // Step 3: Create/update profile with metadata
      if (widget.metadata != null && widget.metadata!.isNotEmpty) {
        debugPrint('Creating profile with metadata...');
        
        final profileSuccess = await authProvider.createOrUpdateProfile(
          profileData: widget.metadata!,
        );

        if (!mounted) return;

        if (!profileSuccess) {
          debugPrint('⚠️ Profile creation failed!');
          debugPrint('Rolling back - deleting auth user...');

          await _rollbackSignupAuthIfNeeded(
            authProvider: authProvider,
            reason: 'createOrUpdateProfile failed',
          );
          
          if (!mounted) return;
          
          await AuthErrorDialog.showError(
            context: context,
            message: 'Registration failed: ${authProvider.errorMessage ?? "Could not save profile"}. Please try again.',
          );
          
          // Navigate back to registration page
          if (!mounted) return;
          Navigator.of(context).pop();
          return;
        }
        
        debugPrint('✓ Profile created successfully!');
      } else {
        debugPrint('⚠️ No metadata provided, skipping profile creation');
      }

      if (!mounted) return;

      // Step 4: Navigate to success page
      Navigator.of(context).pushReplacementNamed(AppRouter.registerSuccess);
    } catch (e) {
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await _rollbackSignupAuthIfNeeded(
        authProvider: authProvider,
        reason: 'unexpected signup verification exception',
      );

      await AuthErrorDialog.showError(
        context: context,
        message: 'Verification failed. Please try again.',
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
    // Dynamic text based on flow type
    final String title = widget.isPasswordReset 
        ? 'Verify Your Identity'
        : 'Enter Verification Code';
    
    final String subtitle = widget.isPasswordReset
      ? 'We sent a 6-digit verification code to\n${widget.email}'
      : 'We sent a 6-digit code to\n${widget.email}';
    
    return PopScope(
      // Prevent accidental back navigation during password reset
      canPop: !widget.isPasswordReset || !_isLoading,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // Show confirmation for password reset flow
        if (widget.isPasswordReset) {
          final navigator = Navigator.of(context);
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cancel Password Reset?'),
              content: const Text(
                'If you go back, you\'ll need to start the password reset process again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Stay'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ) ?? false;
          
          if (shouldPop && mounted) {
            navigator.pop();
          }
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.isPasswordReset ? 'Reset Password' : 'Verify Email'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                widget.isPasswordReset ? Icons.lock_reset : Icons.email_outlined,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    height: 55,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _focusNodes[index],
                      enabled: !_isLoading,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          if (index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else {
                            _focusNodes[index].unfocus();
                            _verifyOtp();
                          }
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else
                ElevatedButton(
                  onPressed: _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Verify',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive code? ",
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                  if (_canResend && !_isLoading)
                    TextButton(
                      onPressed: _resendOtp,
                      child: const Text('Resend'),
                    )
                  else
                    Text(
                      'Resend in ${_resendCountdown}s',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
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
}

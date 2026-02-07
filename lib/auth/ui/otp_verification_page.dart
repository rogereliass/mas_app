import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../auth/logic/auth_provider.dart';
import '../../routing/app_router.dart';
import 'components/auth_error_dialog.dart';

/// OTP Verification Screen
///
/// Allows users to enter the OTP code sent to their phone
class OtpVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final String? password;
  final bool isSignUp;
  final Map<String, dynamic>? metadata;

  const OtpVerificationPage({
    super.key,
    required this.phoneNumber,
    this.password,
    this.isSignUp = false,
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
  static const int _maxAttempts = 3;
  int _resendCount = 0;
  static const int _maxResends = 3;

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

  Future<void> _resendOtp() async {
    if (!_canResend || _isLoading) return;

    // Check if max resend limit reached
    if (_resendCount >= _maxResends) {
      await AuthErrorDialog.showError(
        context: context,
        message: 'Maximum OTP resend limit reached. Please try registering again later.',
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

      // Resend OTP using signUpWithPhone
      if (widget.password != null) {
        final success = await authProvider.signUpWithPhone(
          phoneNumber: widget.phoneNumber,
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
                'OTP resent successfully' +
                (remainingResends > 0 
                    ? '. $remainingResends resend${remainingResends != 1 ? "s" : ""} remaining'
                    : '. This was your last resend'),
              ),
              backgroundColor: Colors.green,
            ),
          );
          _startResendTimer();
        } else {
          await AuthErrorDialog.showError(
            context: context,
            message: authProvider.errorMessage ?? 'Failed to resend OTP',
          );
        }
      } else {
        // Password not available - user needs to go back
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

      // Step 1: Verify OTP
      final otpSuccess = await authProvider.verifySignUpOtp(
        phoneNumber: widget.phoneNumber,
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
        await AuthErrorDialog.showError(
          context: context,
          message: authProvider.errorMessage ?? 'Invalid OTP code' +
              (remainingAttempts > 0 
                  ? '\n$remainingAttempts attempt${remainingAttempts != 1 ? "s" : ""} remaining'
                  : ''),
        );
        return;
      }

      debugPrint('=== OTP VERIFIED SUCCESSFULLY ===');
      debugPrint('Current user: ${authProvider.currentUser?.id}');
      debugPrint('Has metadata: ${widget.metadata != null}');
      debugPrint('Metadata fields: ${widget.metadata?.keys.toList()}');

      // Step 2: Create/update profile with metadata
      if (widget.metadata != null && widget.metadata!.isNotEmpty) {
        debugPrint('Creating profile with metadata...');
        
        final profileSuccess = await authProvider.createOrUpdateProfile(
          profileData: widget.metadata!,
        );

        if (!mounted) return;

        if (!profileSuccess) {
          debugPrint('⚠️ Profile creation failed!');
          debugPrint('Rolling back - deleting auth user...');
          
          // CRITICAL: Delete the auth user to maintain consistency
          // Either both auth user AND profile exist, or neither
          await authProvider.deleteCurrentUser();
          
          if (!mounted) return;
          
          await AuthErrorDialog.showError(
            context: context,
            message: 'Registration failed: ${authProvider.errorMessage ?? "Could not save profile"}. Please try again.',
          );
          
          // Navigate back to registration page
          Navigator.of(context).pop();
          return;
        }
        
        debugPrint('✓ Profile created successfully!');
      } else {
        debugPrint('⚠️ No metadata provided, skipping profile creation');
      }

      if (!mounted) return;

      // Step 3: Navigate to success page
      Navigator.of(context).pushReplacementNamed(AppRouter.registerSuccess);
    } catch (e) {
      if (!mounted) return;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
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
                Icons.phone_android,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Enter Verification Code',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to\n${widget.phoneNumber}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
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
                    style: TextStyle(color: Colors.grey[600]),
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
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

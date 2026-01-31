import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication repository for Supabase operations
///
/// Handles all authentication-related API calls to Supabase
class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Send OTP to phone number for sign in
  ///
  /// Returns true if OTP was sent successfully
  Future<bool> sendSignInOtp({
    required String phoneNumber,
  }) async {
    try {
      // Format phone number
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      await _supabase.auth
          .signInWithOtp(
            phone: formattedPhone,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw AuthException(
                'Request timed out. Please check your connection and try again.',
              );
            },
          );

      return true;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Failed to send OTP: ${e.toString()}');
    }
  }

  /// Verify OTP code for sign in
  ///
  /// Returns the user if verification successful
  Future<User> verifySignInOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    try {
      // Format phone number
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      final response = await _supabase.auth
          .verifyOTP(
            phone: formattedPhone,
            token: otpCode,
            type: OtpType.sms,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw AuthException(
                'Request timed out. Please check your connection and try again.',
              );
            },
          );

      if (response.user == null) {
        throw AuthException('Login failed: No user returned');
      }

      return response.user!;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Login failed: ${e.toString()}');
    }
  }

  /// Send OTP to phone number for sign up
  ///
  /// Returns true if OTP was sent successfully
  Future<bool> sendSignUpOtp({
    required String phoneNumber,
  }) async {
    try {
      // Format phone number
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      await _supabase.auth
          .signInWithOtp(
            phone: formattedPhone,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw AuthException(
                'Request timed out. Please check your connection and try again.',
              );
            },
          );

      return true;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Failed to send OTP: ${e.toString()}');
    }
  }

  /// Verify OTP code for sign up with metadata
  ///
  /// Returns the user if verification successful
  Future<User> verifySignUpOtp({
    required String phoneNumber,
    required String otpCode,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Format phone number
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      final response = await _supabase.auth
          .verifyOTP(
            phone: formattedPhone,
            token: otpCode,
            type: OtpType.sms,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw AuthException(
                'Request timed out. Please check your connection and try again.',
              );
            },
          );

      if (response.user == null) {
        throw AuthException('Registration failed: No user created');
      }

      // Update user metadata if provided
      if (metadata != null && metadata.isNotEmpty) {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: metadata,
          ),
        );
      }

      return response.user!;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  /// Legacy method - kept for backward compatibility
  /// Use sendSignInOtp + verifySignInOtp instead
  @Deprecated('Use sendSignInOtp and verifySignInOtp instead')
  Future<User> signInWithPhone({
    required String phoneNumber,
    required String password,
  }) async {
    throw AuthException(
      'Password authentication is deprecated. Please use OTP verification.',
    );
  }

  /// Legacy method - kept for backward compatibility
  /// Use sendSignUpOtp + verifySignUpOtp instead
  @Deprecated('Use sendSignUpOtp and verifySignUpOtp instead')
  Future<User> signUpWithPhone({
    required String phoneNumber,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    throw AuthException(
      'Password authentication is deprecated. Please use OTP verification.',
    );
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw AuthException('Sign out request timed out');
            },
          );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Sign out failed: ${e.toString()}');
    }
  }

  /// Get current user
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// Check if user is signed in
  bool isSignedIn() {
    return _supabase.auth.currentUser != null;
  }

  /// Get user session
  Session? getCurrentSession() {
    return _supabase.auth.currentSession;
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }

  /// Format phone number with proper handling for spaces and country code
  /// Default country code is +20 (Egypt)
  String _formatPhoneNumber(String phoneNumber) {
    // Remove all spaces, dashes, parentheses, and other non-digit characters except +
    String cleaned = phoneNumber.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (cleaned.isEmpty) {
      throw AuthException('Phone number cannot be empty');
    }

    // If already has country code, validate it
    if (cleaned.startsWith('+')) {
      final digits = cleaned.substring(1);
      if (digits.isEmpty || !RegExp(r'^\d+$').hasMatch(digits)) {
        throw AuthException('Invalid phone number format');
      }
      if (digits.length < 10) {
        throw AuthException('Phone number must be at least 10 digits');
      }
      return cleaned;
    }

    // Remove leading zeros (common in local format)
    cleaned = cleaned.replaceFirst(RegExp(r'^0+'), '');

    // Ensure we have remaining digits after removing zeros
    if (cleaned.isEmpty || !RegExp(r'^\d+$').hasMatch(cleaned)) {
      throw AuthException('Invalid phone number format');
    }

    if (cleaned.length < 10) {
      throw AuthException('Phone number must be at least 10 digits');
    }

    // Default to +20 (Egypt) if no country code provided
    return '+20$cleaned';
  }

  /// Handle auth exceptions and provide user-friendly messages
  AuthException _handleAuthException(AuthException e) {
    String message;

    switch (e.message.toLowerCase()) {
      case String msg when msg.contains('invalid login credentials'):
        message = 'Invalid phone number or password';
        break;
      case String msg when msg.contains('email not confirmed'):
        message = 'Please verify your email address';
        break;
      case String msg when msg.contains('user not found'):
        message = 'Account not found. Please register first';
        break;
      case String msg when msg.contains('user already registered'):
        message = 'This phone number is already registered';
        break;
      case String msg when msg.contains('invalid email'):
        message = 'Please enter a valid email address';
        break;
      case String msg when msg.contains('weak password'):
        message = 'Password is too weak. Use at least 8 characters';
        break;
      case String msg when msg.contains('network'):
        message = 'Network error. Please check your connection';
        break;
      default:
        message = e.message;
    }

    return AuthException(message);
  }
}

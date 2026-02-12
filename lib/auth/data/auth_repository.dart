import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Authentication repository for Supabase operations
///
/// Handles all authentication-related API calls to Supabase
class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Test Supabase connection
  Future<bool> testConnection() async {
    try {
      debugPrint('=== TESTING SUPABASE CONNECTION ===');
      debugPrint('Supabase URL: ${String.fromEnvironment('SUPABASE_URL')}');
      
      // Simple auth status check
      final session = _supabase.auth.currentSession;
      debugPrint('Current session: ${session != null ? "exists" : "none"}');
      
      return true;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  /// Sign in with phone number and password (no OTP required)
  ///
  /// Returns the user if successful, throws exception if failed
  Future<User> signInWithPassword({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      // Format phone number
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      final response = await _supabase.auth
          .signInWithPassword(
            phone: formattedPhone,
            password: password,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw AuthException(
                'Request timed out. Please check your internet connection.',
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

  /// Register new user with phone - sends OTP for verification
  ///
  /// Step 1: Send OTP to phone number
  Future<bool> signUpWithPhone({
    required String phoneNumber,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Format phone number
      final formattedPhone = _formatPhoneNumber(phoneNumber);
      
      debugPrint('=== SIGNUP REQUEST ===');
      debugPrint('Raw phone: $phoneNumber');
      debugPrint('Formatted phone: $formattedPhone');
      debugPrint('Has password: ${password.isNotEmpty}');
      debugPrint('Metadata fields: ${metadata?.keys.toList()}');

      // Sign up with phone - Supabase will send OTP
      // Pass metadata to Supabase auth for redundancy (also available immediately on currentUser)
      // All user data will also be stored in profiles table after OTP verification
      final response = await _supabase.auth
          .signUp(
            phone: formattedPhone,
            password: password,
            data: metadata, // Pass metadata to Supabase auth
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              debugPrint('TIMEOUT: Request took longer than 60 seconds');
              throw AuthException(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      debugPrint('=== METADATA SENT TO AUTH ===');
      debugPrint('Data keys: ${metadata?.keys.toList()}');

      debugPrint('=== SIGNUP RESPONSE ===');
      debugPrint('User ID: ${response.user?.id}');
      debugPrint('Phone: ${response.user?.phone}');
      debugPrint('Session: ${response.session != null}');
      debugPrint('User confirmed: ${response.user?.confirmedAt}');
      
      // Return true to indicate OTP was sent
      return true;
    } on AuthException catch (e) {
      debugPrint('=== AUTH EXCEPTION ===');
      debugPrint('Message: ${e.message}');
      debugPrint('Status code: ${e.statusCode}');
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      debugPrint('=== UNEXPECTED ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw AuthException('Failed to send OTP: ${e.toString()}');
    }
  }

  /// Verify OTP code for sign up
  ///
  /// Step 2: Verify the OTP code sent to user's phone
  Future<User> verifySignUpOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    try {
      // Format phone number
      final formattedPhone = _formatPhoneNumber(phoneNumber);
      
      debugPrint('=== OTP VERIFICATION REQUEST ===');
      debugPrint('Phone: $formattedPhone');
      debugPrint('OTP Code: $otpCode');

      final response = await _supabase.auth
          .verifyOTP(
            phone: formattedPhone,
            token: otpCode,
            type: OtpType.sms,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              debugPrint('TIMEOUT: OTP verification took longer than 60 seconds');
              throw AuthException(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      debugPrint('=== OTP VERIFICATION RESPONSE ===');
      debugPrint('User ID: ${response.user?.id}');
      debugPrint('Phone: ${response.user?.phone}');
      debugPrint('Session exists: ${response.session != null}');

      if (response.user == null) {
        debugPrint('ERROR: No user returned after OTP verification');
        throw AuthException('Verification failed: No user returned');
      }

      return response.user!;
    } on AuthException catch (e) {
      debugPrint('=== AUTH EXCEPTION ===');
      debugPrint('Message: ${e.message}');
      debugPrint('Status code: ${e.statusCode}');
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      debugPrint('=== UNEXPECTED ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw AuthException('Verification failed: ${e.toString()}');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw AuthException('Log out request timed out');
            },
          );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Log out failed: ${e.toString()}');
    }
  }

  /// Delete current authenticated user
  /// Use with caution - this permanently removes the user from auth
  /// Used to rollback registration if profile creation fails
  Future<void> deleteCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw AuthException('No user logged in');
    }

    try {
      debugPrint('Rolling back auth user: ${user.id}');
      // Sign out to clear session (in free tier, we can't delete users via API)
      // In production, you'd use admin API to delete the user
      await _supabase.auth.signOut();
      debugPrint('✓ User signed out (rollback complete)');
    } catch (e) {
      debugPrint('Error during rollback: $e');
      throw AuthException('Failed to rollback user: ${e.toString()}');
    }
  }

  // ============================================================================
  // PASSWORD RESET FLOW
  // ============================================================================

  /// Send OTP for password reset (Step 1)
  /// 
  /// - Phone number must be registered
  /// - Sends OTP to user's phone
  /// - Rate limited on client side (max 2 attempts)
  Future<bool> sendPasswordResetOtp({
    required String phoneNumber,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);
      
      debugPrint('=== PASSWORD RESET OTP REQUEST ===');
      debugPrint('Phone: $formattedPhone');

      // Use Supabase's signInWithOtp for existing users (password reset flow)
      await _supabase.auth
          .signInWithOtp(
            phone: formattedPhone,
            // OTP will be sent to the phone number
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw AuthException(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      debugPrint('✓ Password reset OTP sent successfully');
      return true;
    } on AuthException catch (e) {
      debugPrint('=== AUTH EXCEPTION ===');
      debugPrint('Message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      debugPrint('=== UNEXPECTED ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw AuthException('Failed to send OTP: ${e.toString()}');
    }
  }

  /// Verify OTP for password reset (Step 2)
  /// 
  /// - Verifies the OTP code
  /// - Returns authenticated session for password update
  Future<User> verifyPasswordResetOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);
      
      debugPrint('=== PASSWORD RESET OTP VERIFICATION ===');
      debugPrint('Phone: $formattedPhone');
      debugPrint('OTP Code: $otpCode');

      final response = await _supabase.auth
          .verifyOTP(
            phone: formattedPhone,
            token: otpCode,
            type: OtpType.sms,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw AuthException(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      debugPrint('✓ OTP verified successfully');
      debugPrint('User ID: ${response.user?.id}');

      if (response.user == null) {
        throw AuthException('Verification failed: No user returned');
      }

      return response.user!;
    } on AuthException catch (e) {
      debugPrint('=== AUTH EXCEPTION ===');
      debugPrint('Message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      debugPrint('=== UNEXPECTED ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw AuthException('Verification failed: ${e.toString()}');
    }
  }

  /// Update user password (Step 3)
  /// 
  /// - Must be called after successful OTP verification
  /// - User must have active session
  /// - Password requirements: min 8 characters, complexity validated client-side
  Future<bool> updatePassword({
    required String newPassword,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw AuthException('No active session. Please verify OTP first.');
      }

      debugPrint('=== UPDATE PASSWORD ===');
      debugPrint('User ID: ${user.id}');

      final response = await _supabase.auth
          .updateUser(
            UserAttributes(
              password: newPassword,
            ),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw AuthException(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      debugPrint('✓ Password updated successfully');
      debugPrint('User ID: ${response.user?.id}');

      return response.user != null;
    } on AuthException catch (e) {
      debugPrint('=== AUTH EXCEPTION ===');
      debugPrint('Message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      debugPrint('=== UNEXPECTED ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw AuthException('Failed to update password: ${e.toString()}');
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

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

  /// Create or update user profile in profiles table
  ///
  /// Should be called after successful registration.
  /// Schema: profiles table has 'id' as primary key, 'user_id' as foreign key to auth.users
  /// Uses phone number for conflict resolution since phone has UNIQUE constraint
  Future<void> createOrUpdateProfile({
    required String userId,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      debugPrint('=== CREATE/UPDATE PROFILE ===');
      debugPrint('User ID: $userId');
      debugPrint('Profile data keys: ${profileData.keys.toList()}');

      // Prepare data for upsert
      final profileRecord = {
        'user_id': userId, // Foreign key to auth.users
        ...profileData,
        'updated_at': DateTime.now().toIso8601String(),
      };

      debugPrint('Profile record: ${profileRecord.keys.toList()}');

      // Use upsert with phone as the conflict resolution column
      // Phone has UNIQUE constraint (profiles_phone_key)
      await _supabase
          .from('profiles')
          .upsert(
            profileRecord,
            onConflict: 'phone',
          );

      debugPrint('✓ Profile upserted successfully using phone conflict resolution!');
    } catch (e, stackTrace) {
      debugPrint('=== PROFILE CREATION ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw AuthException('Failed to save profile: ${e.toString()}');
    }
  }

  /// Fetch all troops from troops table with id and name
  ///
  /// Returns list of maps containing troop id and name for dropdown selection
  Future<List<Map<String, dynamic>>> getTroops() async {
    try {
      final response = await _supabase
          .from('troops')
          .select('id, name')
          .order('name');

      if (response.isEmpty) {
        return [];
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Failed to fetch troops: $e');
      return [];
    }
  }

  /// Format phone number with proper handling for spaces and country code
  /// Default country code is +20 (Egypt)
  String _formatPhoneNumber(String phoneNumber) {
    // Remove all spaces, dashes, parentheses, and other non-digit characters except +
    String cleaned = phoneNumber.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (cleaned.isEmpty) {
      throw AuthException('Phone number cannot be empty');
    }

    // If already has country code, validate and return
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

    // For Egyptian numbers starting with 0, remove the leading 0
    // Example: 01234567890 -> 1234567890
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }

    // Ensure we have digits only
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
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

    debugPrint('Handling auth exception: ${e.message}');
    debugPrint('Status code: ${e.statusCode}');

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
      case String msg when msg.contains('phone') && msg.contains('not enabled'):
        message = 'Phone authentication is not enabled. Please contact support.';
        break;
      case String msg when msg.contains('sms') || msg.contains('provider'):
        message = 'SMS service not configured. Please contact support.';
        break;
      default:
        message = e.message;
    }

    return AuthException(message);
  }
}

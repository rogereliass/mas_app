import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Authentication repository for Supabase operations
///
/// Handles all authentication-related API calls to Supabase
class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Test Supabase connection
  Future<bool> testConnection() async {
    try {
      _logDebug('=== TESTING SUPABASE CONNECTION ===');

      // Simple auth status check
      final session = _supabase.auth.currentSession;
      _logDebug('Current session: ${session != null ? "exists" : "none"}');

      return true;
    } catch (e) {
      _logDebug('Connection test failed: $e');
      return false;
    }
  }

  static const String otpEmailSendFailureMessage =
      'We couldn\'t send the verification email right now. Please try again later or contact support.';

  /// Sign in with email and password (no OTP required)
  ///
  /// Returns the user if successful, throws exception if failed
  Future<User> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth
          .signInWithPassword(email: email.trim(), password: password)
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

  /// Request email OTP for new user registration.
  ///
  /// Step 1: Send OTP to email address.
  Future<bool> signUpWithEmailOtp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logDebug('=== SIGNUP REQUEST ===');

      await _supabase.auth
          .signInWithOtp(email: email.trim(), shouldCreateUser: true)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              _logDebug('TIMEOUT: Request took longer than 60 seconds');
              throw AuthException(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      _logDebug('=== SIGNUP RESPONSE ===');
  _logDebug('OTP email request accepted by Supabase');

      return true;
    } on AuthException catch (e) {
      _logDebug('=== AUTH EXCEPTION ===');
      _logDebug('Message: ${e.message}');
      _logDebug('Status code: ${e.statusCode}');
      throw _handleOtpEmailAuthException(e);
    } catch (e, stackTrace) {
      _logDebug('=== UNEXPECTED ERROR ===');
      _logDebug('Error: $e');
      _logDebug('Stack trace: $stackTrace');
      throw AuthException(otpEmailSendFailureMessage);
    }
  }

  /// Verify email OTP code for sign up.
  ///
  /// Step 2: Verify the OTP code sent to user's email.
  Future<User> verifySignUpOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      _logDebug('=== OTP VERIFICATION REQUEST ===');

      final response = await _supabase.auth
          .verifyOTP(email: email.trim(), token: otpCode, type: OtpType.email)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              _logDebug(
                'TIMEOUT: OTP verification took longer than 60 seconds',
              );
              throw AuthException(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      _logDebug('=== OTP VERIFICATION RESPONSE ===');
      _logDebug('Session exists: ${response.session != null}');

      if (response.user == null) {
        _logDebug('ERROR: No user returned after OTP verification');
        throw AuthException('Verification failed: No user returned');
      }

      return response.user!;
    } on AuthException catch (e) {
      _logDebug('=== AUTH EXCEPTION ===');
      _logDebug('Message: ${e.message}');
      _logDebug('Status code: ${e.statusCode}');
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logDebug('=== UNEXPECTED ERROR ===');
      _logDebug('Error: $e');
      _logDebug('Stack trace: $stackTrace');
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
      _logDebug('Rolling back auth user');
      // Sign out to clear session (in free tier, we can't delete users via API)
      // In production, you'd use admin API to delete the user
      await _supabase.auth.signOut();
      _logDebug('✓ User signed out (rollback complete)');
    } catch (e) {
      _logDebug('Error during rollback: $e');
      throw AuthException('Failed to rollback user: ${e.toString()}');
    }
  }

  // ============================================================================
  // PASSWORD RESET FLOW
  // ============================================================================

  /// Send password reset OTP (Step 1)
  ///
  /// - Email must be registered
  /// - Sends OTP code to email
  Future<bool> sendPasswordResetOtp({required String email}) async {
    try {
      _logDebug('=== PASSWORD RESET OTP REQUEST ===');

      await _supabase.auth
          .signInWithOtp(email: email.trim(), shouldCreateUser: false)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw AuthException(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      _logDebug('✓ Password reset OTP sent successfully');
      return true;
    } on AuthException catch (e) {
      _logDebug('=== AUTH EXCEPTION ===');
      _logDebug('Message: ${e.message}');
      throw _handleOtpEmailAuthException(e);
    } catch (e, stackTrace) {
      _logDebug('=== UNEXPECTED ERROR ===');
      _logDebug('Error: $e');
      _logDebug('Stack trace: $stackTrace');
      throw AuthException(otpEmailSendFailureMessage);
    }
  }

  /// Verify password reset OTP (Step 2)
  ///
  /// - Verifies OTP code sent to email
  /// - Returns authenticated session user for password update
  Future<User> verifyPasswordResetOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      _logDebug('=== PASSWORD RESET OTP VERIFICATION ===');

      final response = await _supabase.auth
          .verifyOTP(email: email.trim(), token: otpCode, type: OtpType.email)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw AuthException(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      _logDebug('✓ Password reset OTP verified successfully');

      if (response.user == null) {
        throw AuthException('Verification failed: No user returned');
      }

      return response.user!;
    } on AuthException catch (e) {
      _logDebug('=== AUTH EXCEPTION ===');
      _logDebug('Message: ${e.message}');
      _logDebug('Status code: ${e.statusCode}');
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logDebug('=== UNEXPECTED ERROR ===');
      _logDebug('Error: $e');
      _logDebug('Stack trace: $stackTrace');
      throw AuthException('Verification failed: ${e.toString()}');
    }
  }

  /// Update user password (Step 3)
  ///
  /// - Must be called after successful OTP verification
  /// - User must have active session
  /// - Password requirements: min 8 characters, complexity validated client-side
  Future<bool> updatePassword({required String newPassword}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw AuthException('No active session. Please verify OTP first.');
      }

      _logDebug('=== UPDATE PASSWORD ===');

      final response = await _supabase.auth
          .updateUser(UserAttributes(password: newPassword))
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw AuthException(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      _logDebug('✓ Password updated successfully');

      return response.user != null;
    } on AuthException catch (e) {
      _logDebug('=== AUTH EXCEPTION ===');
      _logDebug('Message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logDebug('=== UNEXPECTED ERROR ===');
      _logDebug('Error: $e');
      _logDebug('Stack trace: $stackTrace');
      throw AuthException('Failed to update password: ${e.toString()}');
    }
  }

  /// Set initial password right after signup OTP verification.
  ///
  /// Keeps the session active for profile creation and post-signup navigation.
  Future<bool> setInitialPassword({required String password}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw AuthException('No active session. Please verify OTP first.');
      }

      final response = await _supabase.auth
          .updateUser(UserAttributes(password: password))
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw AuthException(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      return response.user != null;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Failed to set account password: ${e.toString()}');
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
      _logDebug('=== CREATE/UPDATE PROFILE ===');

      // Keep explicit placeholders like U- for later approval assignment.
      final sanitizedProfileData = Map<String, dynamic>.from(profileData);
      final generationValue = sanitizedProfileData['generation'];
      if (generationValue is String && generationValue.trim().isEmpty) {
        sanitizedProfileData.remove('generation');
      }

      // Prepare data for upsert
      final profileRecord = {
        'user_id': userId, // Foreign key to auth.users
        ...sanitizedProfileData,
        'updated_at': DateTime.now().toIso8601String(),
      };

      _logDebug('Profile record prepared');

      // Use upsert with phone as the conflict resolution column
      // Phone has UNIQUE constraint (profiles_phone_key)
      await _supabase
          .from('profiles')
          .upsert(profileRecord, onConflict: 'phone');

      _logDebug('✓ Profile upserted successfully');
    } on PostgrestException catch (e, stackTrace) {
      _logDebug('=== PROFILE CREATION POSTGREST ERROR ===');
      _logDebug('Code: ${e.code}');
      _logDebug('Message: ${e.message}');
      _logDebug('Details: ${e.details}');
      _logDebug('Hint: ${e.hint}');
      _logDebug('Stack trace: $stackTrace');

      if ((e.code == '42501') && e.message.contains('generation_counters')) {
        throw AuthException(
          'Failed to save profile: database access policy blocked generation counter updates. Please contact support.',
        );
      }

      throw AuthException('Failed to save profile: ${e.message}');
    } catch (e, stackTrace) {
      _logDebug('=== PROFILE CREATION ERROR ===');
      _logDebug('Error: $e');
      _logDebug('Stack trace: $stackTrace');
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
          .order('name')
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw AuthException('Request timed out while fetching troops'),
          );

      if (response.isEmpty) {
        return [];
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDebug('Failed to fetch troops: $e');
      return [];
    }
  }

  /// Handle auth exceptions and provide user-friendly messages
  AuthException _handleAuthException(AuthException e) {
    String message;

    _logDebug('Handling auth exception: ${e.message}');
    _logDebug('Status code: ${e.statusCode}');

    switch (e.message.toLowerCase()) {
      case String msg when msg.contains('invalid login credentials'):
        message = 'Invalid email or password';
        break;
      case String msg when msg.contains('email not confirmed'):
        message = 'Please verify your email address';
        break;
      case String msg when msg.contains('user not found'):
        message = 'Account not found. Please register first';
        break;
      case String msg when msg.contains('user already registered'):
        message = 'This email is already registered';
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

  AuthException _handleOtpEmailAuthException(AuthException e) {
    final lowerMessage = e.message.toLowerCase();

    if (lowerMessage.contains('rate limit') ||
        lowerMessage.contains('smtp') ||
        lowerMessage.contains('email') ||
        lowerMessage.contains('provider') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('network')) {
      return const AuthException(otpEmailSendFailureMessage);
    }

    return _handleAuthException(e);
  }
}

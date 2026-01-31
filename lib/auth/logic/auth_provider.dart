import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/auth_repository.dart';

/// Authentication state management provider
///
/// Manages authentication state across the app using ChangeNotifier
/// Persists user ID and metadata for use throughout the app
class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  StreamSubscription<AuthState>? _authSubscription;
  static SharedPreferences? _cachedPrefs;

  // Cached SharedPreferences getter for performance
  static Future<SharedPreferences> get _prefs async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;

  // User data getters
  String? get userId => _currentUser?.id;
  String? get userEmail => _currentUser?.email;
  String? get userPhone => _currentUser?.phone;
  Map<String, dynamic>? get userMetadata => _currentUser?.userMetadata;
  String? get fullName => _currentUser?.userMetadata?['full_name'] as String?;

  AuthProvider() {
    _initialize();
  }

  /// Initialize auth state and listen to changes
  void _initialize() {
    _currentUser = _authRepository.getCurrentUser();

    // Listen to auth state changes and store subscription for cleanup
    _authSubscription = _authRepository.authStateChanges.listen((AuthState data) {
      _currentUser = data.session?.user;
      if (_currentUser != null) {
        _saveUserData();
      } else {
        _clearUserData();
      }
      notifyListeners();
    });

    // Save user data if already logged in
    if (_currentUser != null) {
      _saveUserData();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Save user data to SharedPreferences for app-wide access
  Future<bool> _saveUserData() async {
    if (_currentUser == null) return false;

    try {
      final prefs = await _prefs;
      
      // Use Future.wait for parallel operations
      await Future.wait<void>([
        prefs.setString('user_id', _currentUser!.id),
        if (_currentUser!.phone != null) 
          prefs.setString('user_phone', _currentUser!.phone!),
        if (_currentUser!.email != null) 
          prefs.setString('user_email', _currentUser!.email!),
        if (_currentUser!.userMetadata?['full_name'] != null)
          prefs.setString(
            'user_full_name',
            _currentUser!.userMetadata!['full_name'] as String,
          ),
        prefs.setBool('is_authenticated', true),
      ]);
      
      return true;
    } catch (e) {
      debugPrint('Error saving user data: $e');
      _setError('Failed to save user data locally');
      return false;
    }
  }

  /// Clear user data from SharedPreferences
  Future<bool> _clearUserData() async {
    try {
      final prefs = await _prefs;
      
      // Use Future.wait for parallel operations
      await Future.wait<void>([
        prefs.remove('user_id'),
        prefs.remove('user_phone'),
        prefs.remove('user_email'),
        prefs.remove('user_full_name'),
        prefs.setBool('is_authenticated', false),
      ]);
      
      return true;
    } catch (e) {
      debugPrint('Error clearing user data: $e');
      return false;
    }
  }

  /// Generic wrapper for auth operations to reduce code duplication
  Future<bool> _executeAuthMethod(
    Future<User> Function() authMethod, {
    String? errorMessage,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await authMethod();
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError(errorMessage ?? 'An unexpected error occurred');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Send OTP for sign in
  Future<bool> sendSignInOtp({
    required String phoneNumber,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _authRepository.sendSignInOtp(phoneNumber: phoneNumber);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to send OTP');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verify OTP for sign in
  Future<bool> verifySignInOtp({
    required String phoneNumber,
    required String otpCode,
  }) async =>
      _executeAuthMethod(
        () => _authRepository.verifySignInOtp(
          phoneNumber: phoneNumber,
          otpCode: otpCode,
        ),
      );

  /// Send OTP for sign up
  Future<bool> sendSignUpOtp({
    required String phoneNumber,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _authRepository.sendSignUpOtp(phoneNumber: phoneNumber);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to send OTP');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verify OTP for sign up
  Future<bool> verifySignUpOtp({
    required String phoneNumber,
    required String otpCode,
    Map<String, dynamic>? metadata,
  }) async =>
      _executeAuthMethod(
        () => _authRepository.verifySignUpOtp(
          phoneNumber: phoneNumber,
          otpCode: otpCode,
          metadata: metadata,
        ),
        errorMessage: 'An unexpected error occurred during registration',
      );

  /// Legacy method - kept for backward compatibility
  @Deprecated('Use sendSignInOtp and verifySignInOtp instead')
  Future<bool> signInWithPhone({
    required String phoneNumber,
    required String password,
  }) async {
    _setError('Password authentication is no longer supported. Please use OTP.');
    return false;
  }

  /// Legacy method - kept for backward compatibility
  @Deprecated('Use sendSignUpOtp and verifySignUpOtp instead')
  Future<bool> signUpWithPhone({
    required String phoneNumber,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    _setError('Password authentication is no longer supported. Please use OTP.');
    return false;
  }

  /// Sign out
  Future<void> signOut() async {
    _setLoading(true);

    try {
      await _authRepository.signOut();
      _currentUser = null;
      await _clearUserData();
    } catch (e) {
      _setError('Failed to sign out');
    } finally {
      _setLoading(false);
    }
  }

  /// Get user ID (helper method for quick access)
  static Future<String?> getUserId() async {
    try {
      final prefs = await _prefs;
      return prefs.getString('user_id');
    } catch (e) {
      return null;
    }
  }

  /// Get user full name (helper method for quick access)
  static Future<String?> getUserFullName() async {
    try {
      final prefs = await _prefs;
      return prefs.getString('user_full_name');
    } catch (e) {
      return null;
    }
  }

  /// Get user phone (helper method for quick access)
  static Future<String?> getUserPhone() async {
    try {
      final prefs = await _prefs;
      return prefs.getString('user_phone');
    } catch (e) {
      return null;
    }
  }

  /// Check if user is authenticated (helper method for quick access)
  static Future<bool> isUserAuthenticated() async {
    try {
      final prefs = await _prefs;
      return prefs.getBool('is_authenticated') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Set error message
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear error manually (for UI)
  void clearError() {
    _clearError();
  }
}

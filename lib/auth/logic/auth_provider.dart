import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/auth_repository.dart';
import '../data/role_repository.dart';
import '../models/user_profile.dart';
import '../models/role.dart';

/// Authentication state management provider
///
/// Manages authentication state across the app using ChangeNotifier
/// Persists user ID and metadata for use throughout the app
class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final RoleRepository _roleRepository = RoleRepository();
  StreamSubscription<AuthState>? _authSubscription;
  static SharedPreferences? _cachedPrefs;

  // Cached SharedPreferences getter for performance
  static Future<SharedPreferences> get _prefs async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  User? _currentUser;
  UserProfile? _currentUserProfile;
  List<Role> _userRoles = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  UserProfile? get currentUserProfile => _currentUserProfile;
  List<Role> get userRoles => _userRoles;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;
  
  /// Get current user's role rank (0 if unauthenticated)
  int get currentUserRoleRank => _currentUserProfile?.roleRank ?? 0;

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
    _authSubscription = _authRepository.authStateChanges.listen((AuthState data) async {
      final previousUser = _currentUser;
      _currentUser = data.session?.user;
      
      if (_currentUser != null) {
        // Load profile first, then save data
        await _loadUserProfile();
        await _loadUserRoles();
        await _saveUserData();
      } else {
        _currentUserProfile = null;
        _userRoles = [];
        await _clearUserData();
      }
      
      // Only notify if state actually changed
      if (previousUser?.id != _currentUser?.id) {
        notifyListeners();
      }
    });

    // Load user profile if already logged in (async)
    if (_currentUser != null) {
      _loadUserProfile().then((_) async {
        await _loadUserRoles();
        await _saveUserData();
        notifyListeners();
      });
    }
  }
  
  /// Load user profile with role rank from database
  Future<void> _loadUserProfile() async {
    if (_currentUser == null) {
      _currentUserProfile = null;
      return;
    }
    
    try {
      _currentUserProfile = await _roleRepository.getUserProfile(_currentUser!.id);
      if (_currentUserProfile != null) {
        debugPrint('✅ Loaded user profile - Role rank: ${_currentUserProfile!.roleRank}');
      } else {
        debugPrint('⚠️ No profile found for user ${_currentUser!.id} - defaulting to public (rank 0)');
      }
    } catch (e) {
      debugPrint('❌ Failed to load user profile: $e');
      // Set profile to null so rank defaults to 0 (public)
      _currentUserProfile = null;
      // Don't throw - allow app to continue with public access
    }
  }

  /// Load user's assigned roles from database
  Future<void> _loadUserRoles() async {
    if (_currentUser == null) {
      _userRoles = [];
      return;
    }
    
    try {
      _userRoles = await _roleRepository.getCurrentUserRoles();
      debugPrint('✅ Loaded ${_userRoles.length} roles for user');
    } catch (e) {
      debugPrint('❌ Failed to load user roles: $e');
      _userRoles = [];
      // Don't throw - allow app to continue without roles
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

  /// Sign in with phone number and password (no OTP)
  Future<bool> signInWithPassword({
    required String phoneNumber,
    required String password,
  }) async =>
      _executeAuthMethod(
        () => _authRepository.signInWithPassword(
          phoneNumber: phoneNumber,
          password: password,
        ),
      );

  /// Sign up with phone - sends OTP for verification
  Future<bool> signUpWithPhone({
    required String phoneNumber,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _authRepository.signUpWithPhone(
        phoneNumber: phoneNumber,
        password: password,
        metadata: metadata,
      );
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
  }) async =>
      _executeAuthMethod(
        () => _authRepository.verifySignUpOtp(
          phoneNumber: phoneNumber,
          otpCode: otpCode,
        ),
        errorMessage: 'An unexpected error occurred during verification',
      );

  /// Create or update user profile with complete data
  Future<bool> createOrUpdateProfile({
    required Map<String, dynamic> profileData,
  }) async {
    if (_currentUser == null) {
      _setError('No user logged in');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      await _authRepository.createOrUpdateProfile(
        userId: _currentUser!.id,
        profileData: profileData,
      );
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to save profile');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get list of troops with id and name from Supabase
  Future<List<Map<String, dynamic>>> getTroops() async {
    try {
      return await _authRepository.getTroops();
    } catch (e) {
      debugPrint('Failed to fetch troops: $e');
      return [];
    }
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

  /// Delete current user (rollback auth if profile creation fails)
  Future<bool> deleteCurrentUser() async {
    try {
      await _authRepository.deleteCurrentUser();
      _currentUser = null;
      await _clearUserData();
      return true;
    } catch (e) {
      debugPrint('Delete user error: $e');
      return false;
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
  
  /// Check if current user can access content with given minimum role rank
  /// Returns true for public content (minRoleRank = 0)
  /// Returns false if user is not authenticated and minRoleRank > 0
  bool canAccessContent(int minRoleRank) {
    if (minRoleRank == 0) return true; // Public content
    if (_currentUserProfile == null) return false; // Not authenticated
    return _currentUserProfile!.canAccess(minRoleRank);
  }

  /// Manually refresh the user profile and roles (e.g. on pull-to-refresh)
  Future<void> refreshProfile() async {
    if (_currentUser != null) {
      await _loadUserProfile();
      await _loadUserRoles();
      notifyListeners();
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

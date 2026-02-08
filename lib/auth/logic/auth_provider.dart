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
  String? _profileLoadError;
  bool _profileLoading = false;

  // Getters
  User? get currentUser => _currentUser;
  UserProfile? get currentUserProfile => _currentUserProfile;
  List<Role> get userRoles => _userRoles;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;
  String? get profileLoadError => _profileLoadError;
  bool get profileLoading => _profileLoading;
  
  /// Get current user's role rank (0 if unauthenticated)
  int get currentUserRoleRank => _currentUserProfile?.roleRank ?? 0;

  // User data getters
  String? get userId => _currentUser?.id;
  String? get userEmail => _currentUser?.email;
  String? get userPhone => _currentUser?.phone;
  Map<String, dynamic>? get userMetadata => _currentUser?.userMetadata;
  
  /// Get full name from user profile or construct from metadata
  String? get fullName {
    // First try from loaded profile (already constructed from first_name + middle_name + last_name)
    if (_currentUserProfile?.fullName != null) {
      return _currentUserProfile!.fullName;
    }
    
    // Fallback: construct from user metadata if profile not loaded
    final metadata = _currentUser?.userMetadata;
    if (metadata != null) {
      final firstName = metadata['first_name'] as String?;
      final middleName = metadata['middle_name'] as String?;
      final lastName = metadata['last_name'] as String?;
      final parts = [firstName, middleName, lastName]
          .where((part) => part != null && part.isNotEmpty);
      if (parts.isNotEmpty) {
        return parts.join(' ');
      }
    }
    
    return null;
  }

  AuthProvider() {
    _initialize();
  }

  /// Initialize auth state and listen to changes
  void _initialize() {
    _currentUser = _authRepository.getCurrentUser();
    debugPrint('🚀 AuthProvider Initialize - Current User: ${_currentUser?.id}');
    debugPrint('   Email: ${_currentUser?.email}, Phone: ${_currentUser?.phone}');

    // Listen to auth state changes and store subscription for cleanup
    _authSubscription = _authRepository.authStateChanges.listen((AuthState data) async {
      final previousUser = _currentUser;
      _currentUser = data.session?.user;
      
      debugPrint('🔔 Auth state changed - User: ${_currentUser?.id}');
      
      if (_currentUser != null) {
        // Load profile first, then save data
        await _loadUserProfile();
        await _loadUserRoles();
        await _saveUserData();
        debugPrint('📢 Notifying listeners after auth state change');
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
      debugPrint('👤 User already logged in, loading profile and roles...');
      _loadUserProfile().then((_) async {
        await _loadUserRoles();
        await _saveUserData();
        debugPrint('📢 Notifying listeners after initial load');
      }).catchError((e) {
        debugPrint('❌ Error in initial load: $e');
        // Still notify listeners so UI can show error state
        notifyListeners();
      });
    } else {
      debugPrint('⚠️ No user logged in at initialization');
    }
  }
  
  /// Load user profile with role rank from database
  Future<void> _loadUserProfile() async {
    if (_currentUser == null) {
      _currentUserProfile = null;
      _profileLoadError = null;
      debugPrint('⚠️ Cannot load profile - no current user');
      return;
    }

    _profileLoading = true;
    _profileLoadError = null;
    notifyListeners();

    try {
      debugPrint('🔄 Loading profile for user: ${_currentUser!.id}');
      _currentUserProfile = await _roleRepository.getUserProfile(_currentUser!.id);
      
      if (_currentUserProfile != null) {
        debugPrint('✅ Loaded user profile:');
        debugPrint('   First Name: ${_currentUserProfile!.firstName}');
        debugPrint('   Middle Name: ${_currentUserProfile!.middleName}');
        debugPrint('   Last Name: ${_currentUserProfile!.lastName}');
        debugPrint('   Full Name: ${_currentUserProfile!.fullName}');
        debugPrint('   Email: ${_currentUserProfile!.email}');
        debugPrint('   Phone: ${_currentUserProfile!.phone}');
        debugPrint('   Role rank: ${_currentUserProfile!.roleRank}');

        // Check if name fields are missing
        if (_currentUserProfile!.firstName == null ||
            _currentUserProfile!.lastName == null) {
          debugPrint('⚠️ WARNING: Name fields are missing in database!');
          debugPrint('   This user may need to re-register or have their profile updated.');
          _profileLoadError = 'Profile data is incomplete. Please contact support.';
        }
        _profileLoadError = null;
      } else {
        debugPrint('⚠️ No profile found for user ${_currentUser!.id}');
        _currentUserProfile = null;
        _profileLoadError = 'User profile not found in database. Please contact support or re-register.';
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to load user profile: $e');
      debugPrint('   StackTrace: $stackTrace');
      // Set profile to null and store error message
      _currentUserProfile = null;
      _profileLoadError = 'Failed to load profile: ${e.toString()}. Please check your internet connection or contact support.';
    } finally {
      _profileLoading = false;
      notifyListeners();
    }
  }

  /// Load user's assigned roles from database
  Future<void> _loadUserRoles() async {
    if (_currentUser == null) {
      _userRoles = [];
      debugPrint('⚠️ No current user, skipping role load');
      return;
    }
    
    try {
      debugPrint('🔄 Loading roles for user ${_currentUser!.id}...');
      _userRoles = await _roleRepository.getCurrentUserRoles();
      debugPrint('✅ Loaded ${_userRoles.length} roles for user');
      if (_userRoles.isNotEmpty) {
        debugPrint('   Roles: ${_userRoles.map((r) => '${r.name} (rank ${r.rank})').join(', ')}');
      } else {
        debugPrint('   ⚠️ User has no roles assigned');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to load user roles: $e');
      debugPrint('   StackTrace: $stackTrace');
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

      // Build list of futures to save in parallel
      final saveTasks = <Future<void>>[
        prefs.setString('user_id', _currentUser!.id),
        prefs.setBool('is_authenticated', true),
      ];

      // Save basic user data
      if (_currentUser!.phone != null) {
        saveTasks.add(prefs.setString('user_phone', _currentUser!.phone!));
      }
      if (_currentUser!.email != null) {
        saveTasks.add(prefs.setString('user_email', _currentUser!.email!));
      }

      // Save all profile data if available
      if (_currentUserProfile != null) {
        final profile = _currentUserProfile!;

        // Save name fields
        if (profile.firstName != null) {
          saveTasks.add(prefs.setString('user_first_name', profile.firstName!));
        }
        if (profile.middleName != null) {
          saveTasks.add(prefs.setString('user_middle_name', profile.middleName!));
        }
        if (profile.lastName != null) {
          saveTasks.add(prefs.setString('user_last_name', profile.lastName!));
        }
        if (profile.fullName != null) {
          saveTasks.add(prefs.setString('user_full_name', profile.fullName!));
        }

        // Save other profile fields
        if (profile.nameAr != null) {
          saveTasks.add(prefs.setString('user_name_ar', profile.nameAr!));
        }
        if (profile.email != null) {
          saveTasks.add(prefs.setString('user_email', profile.email!));
        }
        if (profile.phone != null) {
          saveTasks.add(prefs.setString('user_phone', profile.phone!));
        }
        if (profile.address != null) {
          saveTasks.add(prefs.setString('user_address', profile.address!));
        }
        if (profile.birthdate != null) {
          saveTasks.add(prefs.setString('user_birthdate', profile.birthdate!.toIso8601String()));
        }
        if (profile.gender != null) {
          saveTasks.add(prefs.setString('user_gender', profile.gender!));
        }
        if (profile.signupTroopId != null) {
          saveTasks.add(prefs.setString('user_signup_troop', profile.signupTroopId!));
        }
        if (profile.generation != null) {
          saveTasks.add(prefs.setString('user_generation', profile.generation!));
        }

        saveTasks.add(prefs.setInt('user_role_rank', profile.roleRank));
      }

      // Use Future.wait for parallel operations
      await Future.wait(saveTasks);

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
        prefs.remove('user_first_name'),
        prefs.remove('user_middle_name'),
        prefs.remove('user_last_name'),
        prefs.remove('user_full_name'),
        prefs.remove('user_name_ar'),
        prefs.remove('user_address'),
        prefs.remove('user_birthdate'),
        prefs.remove('user_gender'),
        prefs.remove('user_signup_troop'),
        prefs.remove('user_generation'),
        prefs.remove('user_role_rank'),
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
      await _saveUserData();
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

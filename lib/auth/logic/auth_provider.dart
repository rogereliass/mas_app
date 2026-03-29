import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/auth_repository.dart';
import '../data/role_repository.dart';
import '../models/user_profile.dart';
import '../models/role.dart';
import '../../core/data/persistent_query_cache.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/utils/ttl_cache.dart';
import '../../core/utils/fcm_service.dart';
import '../../offline/offline_storage.dart';
import '../../routing/app_router.dart';
import '../../routing/navigation_service.dart';

/// Authentication state management provider
///
/// Manages authentication state across the app using ChangeNotifier
/// Persists user ID and metadata for use throughout the app
class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final RoleRepository _roleRepository = RoleRepository();
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  static SharedPreferences? _cachedPrefs;
  static const int _profileLoadAttempts = 2;
  static const Duration _profileRetryDelay = Duration(milliseconds: 700);
  static const Duration _offlineIdentityTtl = Duration(days: 7);
  static const Duration _offlineIdentityStaleGrace = Duration(days: 2);

  // TTL caching for troops list
  static const Duration _troopsCacheTtl = Duration(minutes: 60);
  final TtlCache<String, List<Map<String, dynamic>>> _troopsCache = TtlCache();

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  // Cached SharedPreferences getter for performance
  static Future<SharedPreferences> get _prefs async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  /// Migrate from old encrypted storage to plain storage
  /// Detects if data is encrypted (base64 encoded with iv/data payload) and clears it
  Future<void> _migrateFromEncryptedStorage() async {
    try {
      final prefs = await _prefs;

      // Check if we have the migration marker
      final migrated = prefs.getBool('_storage_migrated_v1') ?? false;
      if (migrated) {
        _logDebug('[OK] Storage already migrated');
        return;
      }

      _logDebug('[SYNC] Migrating from encrypted storage to plain storage...');

      // List of keys that were previously encrypted
      final encryptedKeys = [
        'user_phone',
        'user_email',
        'user_first_name',
        'user_middle_name',
        'user_last_name',
        'user_full_name',
        'user_name_ar',
        'user_address',
        'user_birthdate',
        'user_gender',
        'user_signup_troop',
        'user_generation',
      ];

      // Check if any value looks encrypted (contains base64 payload with iv/data)
      bool hasEncryptedData = false;
      for (final key in encryptedKeys) {
        final value = prefs.getString(key);
        if (value != null && _looksLikeEncryptedData(value)) {
          hasEncryptedData = true;
          break;
        }
      }

      if (hasEncryptedData) {
        _logDebug('[WARN] Detected old encrypted data, clearing all user data...');
        // Clear all user data to reset to clean state
        await _clearUserData();
      }

      // Mark migration as complete
      await prefs.setBool('_storage_migrated_v1', true);
      _logDebug('[OK] Storage migration complete');
    } catch (e) {
      _logDebug('[WARN] Migration error (non-fatal): $e');
      // Non-fatal - continue anyway
    }
  }

  /// Check if a string looks like encrypted data (base64 with JSON payload)
  bool _looksLikeEncryptedData(String value) {
    // Encrypted data is base64 encoded JSON with 'iv' and 'data' keys
    // Pattern: long base64 string (>50 chars) without spaces
    if (value.length < 50) return false;
    if (value.contains(' ')) return false;

    // Try to detect base64 pattern
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]+=*$');
    return base64Pattern.hasMatch(value);
  }

  User? _currentUser;
  UserProfile? _currentUserProfile;
  List<Role> _userRoles = [];
  String? _selectedRoleName;
  bool _isLoading = false;
  String? _errorMessage;
  String? _profileLoadError;
  bool _profileLoading = false;
  bool _usingCachedIdentity = false;
  Future<void>? _bootstrapInFlight;

  // Getters
  User? get currentUser => _currentUser;
  UserProfile? get currentUserProfile => _currentUserProfile;
  List<Role> get userRoles => _userRoles;
  String? get selectedRoleName => _selectedRoleName;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;
  String? get profileLoadError => _profileLoadError;
  bool get profileLoading => _profileLoading;
  bool get isUsingCachedIdentity => _usingCachedIdentity;

  /// Get current user's role rank (0 if unauthenticated)
  int get currentUserRoleRank => _currentUserProfile?.roleRank ?? 0;

  /// Effective role rank for the globally selected role context.
  /// Falls back to the current user's highest rank when no role is selected.
  int get selectedRoleRank {
    if (_selectedRoleName == null) return currentUserRoleRank;
    final rank = getRankForRole(_selectedRoleName!);
    return rank > 0 ? rank : currentUserRoleRank;
  }

  /// Get specific role by name from user's assigned roles
  Role? getRoleByName(String roleName) {
    try {
      return _userRoles.firstWhere(
        (role) => role.name.toLowerCase() == roleName.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get rank for a specific role name (returns 0 if role not found)
  int getRankForRole(String roleName) {
    final role = getRoleByName(roleName);
    return role?.rank ?? 0;
  }

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
      final parts = [
        firstName,
        middleName,
        lastName,
      ].where((part) => part != null && part.isNotEmpty);
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
    _logDebug('[INIT] AuthProvider Initialize');

    // Migrate from old encrypted storage if needed
    _migrateFromEncryptedStorage()
        .then((_) {
          _logDebug('[OK] Migration check complete, continuing initialization');
        })
        .catchError((e) {
          _logDebug('[WARN] Migration failed (non-fatal): $e');
        });

    // Listen to connectivity changes so cached identity can auto-refresh on reconnect.
    _connectivitySubscription = ConnectivityService.instance.statusStream.listen((
      isOnline,
    ) {
      if (!isOnline) {
        return;
      }
      if (_currentUser == null || !_usingCachedIdentity || _profileLoading) {
        return;
      }
      unawaited(refreshProfile());
    });

    // Listen to auth state changes and store subscription for cleanup
    _authSubscription = _authRepository.authStateChanges.listen((AuthState data) async {
      final previousUserId = _currentUser?.id;
      _currentUser = data.session?.user;

      if (data.event == AuthChangeEvent.passwordRecovery && _currentUser != null) {
        final email = _currentUser!.email;
        if (email != null && email.isNotEmpty) {
          NavigationService.navigatorKey.currentState?.pushNamed(
            AppRouter.resetPassword,
            arguments: {'email': email},
          );
        }
      }

      _logDebug('[AUTH] Auth state changed');

      if (_currentUser != null) {
        await _ensureAuthenticatedBootstrap();
      } else {
        _currentUserProfile = null;
        _userRoles = [];
        _usingCachedIdentity = false;
        await _clearUserData(previousUserIdForCache: previousUserId);
        await _deactivateFcmTokenForSignedOutUser();

        // Notify listeners since user logged out
        notifyListeners();
      }
    });

    // Load user profile if already logged in (async)
    if (_currentUser != null) {
      _logDebug('[USER] User already logged in, loading profile and roles...');
      unawaited(_ensureAuthenticatedBootstrap());
    } else {
      _logDebug('[WARN] No user logged in at initialization');
    }
  }

  Future<void> _ensureAuthenticatedBootstrap() async {
    final inFlight = _bootstrapInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final operation = _bootstrapAuthenticatedState();
    _bootstrapInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_bootstrapInFlight, operation)) {
        _bootstrapInFlight = null;
      }
    }
  }

  Future<void> _bootstrapAuthenticatedState() async {
    if (_currentUser == null) {
      return;
    }

    _profileLoading = true;
    notifyListeners();

    var hydrated = false;
    UserProfile? hydratedProfileSnapshot;
    var hydratedRolesSnapshot = <Role>[];

    try {
      hydrated = await _hydrateOfflineIdentitySnapshot();
      if (hydrated) {
        _usingCachedIdentity = true;
        hydratedProfileSnapshot = _currentUserProfile;
        hydratedRolesSnapshot = List<Role>.from(_userRoles);
        notifyListeners();
      }

      final isOnline = ConnectivityService.instance.isOnline;
      if (!isOnline && hydrated) {
        _profileLoadError ??= 'Offline mode: using cached profile data.';
        _profileLoading = false;
        notifyListeners();
        return;
      }

      if (!isOnline && !hydrated) {
        _profileLoadError =
            'Offline mode: no cached profile available yet. Connect once to initialize offline access.';
        _profileLoading = false;
        notifyListeners();
        return;
      }

      await _loadUserProfile(notifyOnComplete: false);
      await _loadUserRoles();

      if (_currentUserProfile == null && hydrated && hydratedProfileSnapshot != null) {
        _currentUserProfile = hydratedProfileSnapshot;
      }

      if (_userRoles.isEmpty && hydrated && hydratedRolesSnapshot.isNotEmpty) {
        _userRoles = hydratedRolesSnapshot;
      }

      await _hydrateAndNormalizeSelectedRole();
      await _saveUserData();
      await _persistOfflineIdentitySnapshot();
      await _syncFcmTokenWithCurrentProfile();
      _usingCachedIdentity = false;
    } catch (e) {
      _logDebug('[ERROR] Error in authenticated bootstrap: $e');
      if (!hydrated) {
        _profileLoadError = 'Failed to initialize profile data: $e';
      }
    } finally {
      _profileLoading = false;
      notifyListeners();
    }
  }

  /// Load user profile with role rank from database
  ///
  /// [notifyOnComplete] - If false, doesn't call notifyListeners() when done
  /// and doesn't reset _profileLoading flag. Useful during initialization when
  /// we want to load both profile and roles before notifying UI.
  Future<void> _loadUserProfile({bool notifyOnComplete = true}) async {
    if (_currentUser == null) {
      _currentUserProfile = null;
      _profileLoadError = null;
      _logDebug('[WARN] Cannot load profile - no current user');
      return;
    }

    _logDebug('[SYNC] Loading user profile for user ID: ${_currentUser!.id}');

    // Only set loading flag if we're managing it ourselves (notifyOnComplete = true)
    if (notifyOnComplete) {
      _profileLoading = true;
      notifyListeners();
    }

    try {
      _currentUserProfile = await _fetchUserProfileWithRetry(_currentUser!.id);

      _logDebug(
        '[PROFILE] Profile fetch result: ${_currentUserProfile != null ? "SUCCESS" : "NULL"}',
      );

      if (_currentUserProfile != null) {
        _logDebug('[OK] Loaded user profile: ${_currentUserProfile!.fullName}');
        _logDebug('   First Name: ${_currentUserProfile!.firstName}');
        _logDebug('   Middle Name: ${_currentUserProfile!.middleName}');
        _logDebug('   Last Name: ${_currentUserProfile!.lastName}');
        _logDebug('   Role Rank: ${_currentUserProfile!.roleRank}');

        // Check if name fields are missing
        if (_currentUserProfile!.firstName == null ||
            _currentUserProfile!.lastName == null) {
          _logDebug('[WARN] WARNING: Name fields are missing in database');
          _profileLoadError =
              'Profile data is incomplete. Please contact support.';
        } else {
          _profileLoadError = null;
        }
      } else {
        _logDebug('[ERROR] No profile found for current user');
        _currentUserProfile = null;
        _profileLoadError =
            'User profile not found in database. Please contact support or re-register.';
      }
    } catch (e, stackTrace) {
      _logDebug('[ERROR] Failed to load user profile: $e');
      _logDebug('   StackTrace: $stackTrace');
      // Set profile to null and store error message
      _currentUserProfile = null;
      _profileLoadError =
          'Failed to load profile: ${e.toString()}. Please check your internet connection or contact support.';
    } finally {
      // Only reset loading flag and notify if we're managing it ourselves
      if (notifyOnComplete) {
        _profileLoading = false;
        notifyListeners();
      }
    }
  }

  /// Fetch profile with a single retry to tolerate transient startup/network issues.
  Future<UserProfile?> _fetchUserProfileWithRetry(String userId) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _profileLoadAttempts; attempt++) {
      try {
        final profile = await _roleRepository.getUserProfile(userId);
        if (profile != null) {
          return profile;
        }

        _logDebug(
          '[WARN] Profile fetch returned null (attempt $attempt/$_profileLoadAttempts)',
        );
      } catch (e) {
        lastError = e;
        _logDebug(
          '[WARN] Profile fetch failed (attempt $attempt/$_profileLoadAttempts): $e',
        );
      }

      if (attempt < _profileLoadAttempts) {
        await Future.delayed(_profileRetryDelay);
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    return null;
  }

  /// Load user's assigned roles from database
  Future<void> _loadUserRoles() async {
    if (_currentUser == null) {
      _userRoles = [];
      _logDebug('[WARN] No current user, skipping role load');
      return;
    }

    final previousRoles = List<Role>.from(_userRoles);

    try {
      _logDebug('[SYNC] Loading roles for user');
      _userRoles = await _roleRepository.getCurrentUserRoles();
      await _hydrateAndNormalizeSelectedRole();
      _logDebug('[OK] Loaded ${_userRoles.length} roles for user');
    } catch (e, stackTrace) {
      _logDebug('[ERROR] Failed to load user roles: $e');
      _logDebug('   StackTrace: $stackTrace');
      if (_usingCachedIdentity && previousRoles.isNotEmpty) {
        _userRoles = previousRoles;
        await _hydrateAndNormalizeSelectedRole();
      } else {
        _userRoles = [];
        _selectedRoleName = null;
      }
      // Don't throw - allow app to continue with cached roles when available.
    }
  }

  /// Initializes selected role from local storage and ensures it's still valid
  /// for the current authenticated user's available role list.
  Future<void> _hydrateAndNormalizeSelectedRole() async {
    final prefs = await _prefs;

    _selectedRoleName ??= prefs.getString('selected_role_name');

    if (_userRoles.isEmpty) {
      _selectedRoleName = null;
      await prefs.remove('selected_role_name');
      return;
    }

    final isValid =
        _selectedRoleName != null &&
        _userRoles.any(
          (r) => r.name.toLowerCase() == _selectedRoleName!.toLowerCase(),
        );

    if (!isValid) {
      _selectedRoleName = _userRoles.first.name;
      await prefs.setString('selected_role_name', _selectedRoleName!);
    }
  }

  /// Sets the globally selected role context for the whole app.
  ///
  /// Passing null will auto-fallback to the first assigned role (if available).
  Future<void> setSelectedRole(String? roleName) async {
    final prefs = await _prefs;

    if (_userRoles.isEmpty) {
      _selectedRoleName = null;
      await prefs.remove('selected_role_name');
      notifyListeners();
      return;
    }

    String? nextRole = roleName?.trim();
    if (nextRole != null && nextRole.isEmpty) nextRole = null;

    if (nextRole != null) {
      final exists = _userRoles.any(
        (r) => r.name.toLowerCase() == nextRole!.toLowerCase(),
      );
      if (!exists) {
        nextRole = _userRoles.first.name;
      }
    }

    nextRole ??= _userRoles.first.name;

    if (_selectedRoleName == nextRole) return;

    _selectedRoleName = nextRole;
    await prefs.setString('selected_role_name', nextRole);
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
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
        prefs.remove('user_phone').then((_) {}),
        prefs.remove('user_email').then((_) {}),
        prefs.remove('user_first_name').then((_) {}),
        prefs.remove('user_middle_name').then((_) {}),
        prefs.remove('user_last_name').then((_) {}),
        prefs.remove('user_name_ar').then((_) {}),
        prefs.remove('user_address').then((_) {}),
        prefs.remove('user_birthdate').then((_) {}),
        prefs.remove('user_gender').then((_) {}),
        prefs.remove('user_generation').then((_) {}),
      ];

      // Persist only minimal non-sensitive context required for app bootstrap.
      if (_currentUserProfile != null) {
        final profile = _currentUserProfile!;
        if (profile.fullName != null) {
          saveTasks.add(prefs.setString('user_full_name', profile.fullName!));
        }
        if (profile.signupTroopId != null) {
          saveTasks.add(
            prefs.setString('user_signup_troop', profile.signupTroopId!),
          );
        }

        saveTasks.add(prefs.setInt('user_role_rank', profile.roleRank));
      }

      // Use Future.wait for parallel operations
      await Future.wait(saveTasks);

      return true;
    } catch (e) {
      _logDebug('Error saving user data: $e');
      _setError('Failed to save user data locally');
      return false;
    }
  }

  /// Clear user data from SharedPreferences
  Future<bool> _clearUserData({String? previousUserIdForCache}) async {
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
        prefs.remove('selected_role_name'),
        prefs.setBool('is_authenticated', false),
      ]);

      final cacheUserId = previousUserIdForCache ?? _currentUser?.id;
      if (cacheUserId != null && cacheUserId.trim().isNotEmpty) {
        await PersistentQueryCache.invalidate(_offlineIdentityKey(cacheUserId));
      }

      try {
        await OfflineStorageService.clearAll();
      } catch (e) {
        _logDebug('Failed to clear offline files on sign out: $e');
      }

      _selectedRoleName = null;

      return true;
    } catch (e) {
      _logDebug('Error clearing user data: $e');
      return false;
    }
  }

  String _offlineIdentityKey(String userId) =>
      'auth:identity:${userId.trim()}';

  Future<void> _persistOfflineIdentitySnapshot() async {
    if (_currentUser == null || _currentUserProfile == null) {
      return;
    }

    final payload = <String, dynamic>{
      'schema_version': 1,
      'user_id': _currentUser!.id,
      'profile': _currentUserProfile!.toJson(),
      'roles': _userRoles.map((role) => role.toJson()).toList(growable: false),
      'selected_role_name': _selectedRoleName,
      'role_rank': _currentUserProfile!.roleRank,
    };

    await PersistentQueryCache.write(
      key: _offlineIdentityKey(_currentUser!.id),
      payload: payload,
      ttl: _offlineIdentityTtl,
    );
  }

  Future<bool> _hydrateOfflineIdentitySnapshot() async {
    if (_currentUser == null) {
      return false;
    }

    final entry = await PersistentQueryCache.read<Map<String, dynamic>>(
      key: _offlineIdentityKey(_currentUser!.id),
      parser: _parseOfflineIdentitySnapshot,
    );
    if (entry == null) {
      return false;
    }

    final isOnline = ConnectivityService.instance.isOnline;
    if (entry.isExpired) {
      if (isOnline) {
        await PersistentQueryCache.invalidate(_offlineIdentityKey(_currentUser!.id));
        return false;
      }

      final savedAt = entry.savedAt;
      if (savedAt == null ||
          DateTime.now().difference(savedAt) >
              (_offlineIdentityTtl + _offlineIdentityStaleGrace)) {
        await PersistentQueryCache.invalidate(_offlineIdentityKey(_currentUser!.id));
        return false;
      }

      _profileLoadError =
          'Offline mode: using stale cached profile. Connect to refresh permissions.';
    }

    final payload = entry.data;
    final profileRaw = payload['profile'];
    if (profileRaw is! Map) {
      await PersistentQueryCache.invalidate(_offlineIdentityKey(_currentUser!.id));
      return false;
    }

    try {
      final profileMap = profileRaw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      _currentUserProfile = UserProfile.fromJson(profileMap);

      final rolesRaw = payload['roles'];
      final hydratedRoles = <Role>[];
      if (rolesRaw is List) {
        for (final raw in rolesRaw) {
          if (raw is! Map) continue;
          try {
            final roleMap = raw.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            hydratedRoles.add(Role.fromJson(roleMap));
          } catch (_) {
            // Ignore malformed role entries while keeping remaining roles.
          }
        }
      }
      _userRoles = hydratedRoles;

      final selectedRole = payload['selected_role_name'];
      _selectedRoleName = selectedRole is String && selectedRole.trim().isNotEmpty
          ? selectedRole
          : _selectedRoleName;

      _profileLoadError = null;
      return true;
    } catch (_) {
      await PersistentQueryCache.invalidate(_offlineIdentityKey(_currentUser!.id));
      return false;
    }
  }

  Map<String, dynamic>? _parseOfflineIdentitySnapshot(Object? payload) {
    if (payload is! Map) {
      return null;
    }

    return payload.map((key, value) => MapEntry(key.toString(), value));
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

      // Immediately load profile and roles after successful authentication
      // Don't notify until both are loaded to avoid showing no-role state
      await _loadUserProfile(notifyOnComplete: false);
      await _loadUserRoles();
      await _saveUserData();
      await _persistOfflineIdentitySnapshot();
      await _syncFcmTokenWithCurrentProfile();
      _usingCachedIdentity = false;

      // Manually notify after both profile and roles are loaded
      notifyListeners();

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

  /// Sign in with email and password (no OTP)
  Future<bool> signInWithPassword({
    required String email,
    required String password,
  }) async => _executeAuthMethod(
    () => _authRepository.signInWithPassword(
      email: email,
      password: password,
    ),
  );

  /// Sign up with email OTP - sends OTP for verification
  Future<bool> signUpWithEmailOtp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _authRepository.signUpWithEmailOtp(
        email: email,
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
    required String email,
    required String otpCode,
  }) async => _executeAuthMethod(
    () => _authRepository.verifySignUpOtp(
      email: email,
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
  Future<List<Map<String, dynamic>>> getTroops({
    bool forceRefresh = false,
  }) async {
    // Check cache if not forcing refresh
    if (!forceRefresh) {
      final cachedTroops = _troopsCache.get('troops');
      if (cachedTroops != null) {
        _logDebug('[CACHE] Using cached troops (${cachedTroops.length} items)');
        return cachedTroops;
      }
    }

    try {
      final troops = await _authRepository.getTroops();
      _troopsCache.set('troops', troops, _troopsCacheTtl);
      _logDebug(
        '[OK] Loaded ${troops.length} troops (cached for ${_troopsCacheTtl.inMinutes}min)',
      );
      return troops;
    } catch (e) {
      _logDebug('Failed to fetch troops: $e');
      return [];
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _setLoading(true);

    try {
      final previousUserId = _currentUser?.id;
      await _authRepository.signOut();
      _currentUser = null;
      await _clearUserData(previousUserIdForCache: previousUserId);
    } catch (e) {
      _setError('Failed to log out');
    } finally {
      _setLoading(false);
    }
  }

  /// Delete current user (rollback auth if profile creation fails)
  Future<bool> deleteCurrentUser() async {
    try {
      final previousUserId = _currentUser?.id;
      await _authRepository.deleteCurrentUser();
      _currentUser = null;
      await _clearUserData(previousUserIdForCache: previousUserId);
      return true;
    } catch (e) {
      _logDebug('Delete user error: $e');
      _setError(
        'Could not fully clean up the failed registration account. Please contact support before retrying.',
      );
      return false;
    }
  }

  // ============================================================================
  // PASSWORD RESET FLOW
  // ============================================================================

  /// Send password reset OTP (Step 1)
  ///
  /// Sends a verification code to the registered email address.
  Future<bool> sendPasswordResetOtp({required String email}) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _authRepository.sendPasswordResetOtp(
        email: email,
      );
      return success;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to send verification code');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verify password reset OTP (Step 2)
  ///
  /// Verifies OTP code and creates a temporary authenticated session
  /// to allow password update.
  Future<bool> verifyPasswordResetOtp({
    required String email,
    required String otpCode,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authRepository.verifyPasswordResetOtp(
        email: email,
        otpCode: otpCode,
      );

      _currentUser = user;
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to verify OTP');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update password after OTP verification (Step 3)
  ///
  /// Updates user password - must have active session from OTP verification
  /// Returns true if password updated successfully
  Future<bool> updatePassword({required String newPassword}) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _authRepository.updatePassword(
        newPassword: newPassword,
      );

      if (success) {
        // Sign out after password reset for security
        await signOut();
      }

      return success;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to update password');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Set initial password after signup OTP verification.
  ///
  /// Unlike reset flow, this does not sign the user out.
  Future<bool> setInitialPassword({required String password}) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _authRepository.setInitialPassword(
        password: password,
      );
      return success;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to set account password');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

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
      if (_profileLoading) {
        return;
      }

      _profileLoading = true;
      notifyListeners();

      try {
        // Load both profile and roles before notifying to avoid race condition
        await _loadUserProfile(notifyOnComplete: false);
        await _loadUserRoles();
        await _saveUserData();
        await _persistOfflineIdentitySnapshot();
        await _syncFcmTokenWithCurrentProfile();
        _usingCachedIdentity = false;
      } finally {
        _profileLoading = false;
        // Manually notify after both are loaded
        notifyListeners();
      }
    }
  }

  Future<void> _syncFcmTokenWithCurrentProfile() async {
    final profileId = _currentUserProfile?.id;
    if (profileId == null || profileId.trim().isEmpty) {
      return;
    }

    await FcmService.instance.syncTokenForProfile(profileId: profileId);
  }

  Future<void> _deactivateFcmTokenForSignedOutUser() async {
    await FcmService.instance.clearTokenForSignedOutUser();
  }

  /// Set loading state
  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  /// Set error message
  void _setError(String message) {
    if (_errorMessage == message) return;
    _errorMessage = message;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear error manually (for UI)
  void clearError() {
    _clearError();
  }

  /// Check if email already exists in profiles table
  Future<bool> checkEmailExists(String email) async {
    try {
      final result = await _authRepository.checkEmailExists(email);
      return result;
    } catch (e) {
      _logDebug('Error checking email existence: $e');
      rethrow;
    }
  }
}

